#Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License").
#  You may not use this file except in compliance with the License.
#  A copy of the License is located at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  or in the "license" file accompanying this file. This file is distributed
#  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
#  express or implied. See the License for the specific language governing
#  permissions and limitations under the License.

'''
Wraps the GuardDuty Investigation APIs: building trigger prompts, creating
investigations (with quota guard + idempotency), polling for results, and
listing past investigations.
'''

import re
import time
import hashlib
from datetime import datetime, timezone
from typing import Dict, List, Optional

from botocore.exceptions import ClientError

from core import constants
from core.enablement import InvestigationError


def build_trigger_prompt(kind: str, value: Optional[str] = None) -> str:
    '''
    Build a valid triggerPrompt for the requested analysis kind.
    GuardDuty infers the analysis type from the prompt content, so each prompt
    contains exactly one finding id OR one account id (or org phrasing).
    '''
    if kind == 'finding':
        if not re.match(constants.FINDING_ID_PATTERN, value or ''):
            raise InvestigationError(
                f"'{value}' is not a valid finding id (expected 32 hex characters)."
            )
        prompt = f'Investigate finding {value}'
    elif kind == 'account':
        if not re.match(constants.ACCOUNT_ID_PATTERN, value or ''):
            raise InvestigationError(
                f"'{value}' is not a valid account id (expected 12 digits)."
            )
        prompt = f'Analyze findings in account with id {value}'
    elif kind == 'org':
        prompt = 'Analyze findings in my organization'
    else:
        raise InvestigationError(f'Unknown analysis kind: {kind}')

    if len(prompt) > constants.MAX_TRIGGER_PROMPT_LEN:
        raise InvestigationError('Trigger prompt exceeds the 2048 character limit.')
    return prompt


def _client_token(detector_id: str, trigger_prompt: str) -> str:
    '''
    Deterministic idempotency token so retries of the same logical request do
    not consume additional quota. Bucketed to the current hour so an
    intentional re-run later still creates a fresh investigation.
    '''
    hour = datetime.now(timezone.utc).strftime('%Y%m%d%H')
    raw = f'{detector_id}|{trigger_prompt}|{hour}'
    return hashlib.sha256(raw.encode('utf-8')).hexdigest()[:64]


def check_quota(gd_client, detector_id: str, assume_yes: bool) -> None:
    '''
    Warn (and require confirmation) when approaching the preview quotas.
    Counts only non-failed investigations, matching how the quota is applied.
    '''
    summaries = _list_all_summaries(gd_client, detector_id)

    today = datetime.now(timezone.utc).date()
    counted = [s for s in summaries if s.get('Status') != constants.STATUS_FAILED]
    total = len(counted)
    today_count = sum(
        1 for s in counted
        if _start_date(s) == today
    )

    if today_count >= constants.MAX_INVESTIGATIONS_PER_DAY:
        raise InvestigationError(
            f'Daily preview quota reached ({today_count}/'
            f'{constants.MAX_INVESTIGATIONS_PER_DAY} investigations today).'
        )
    if total >= constants.MAX_INVESTIGATIONS_TOTAL:
        raise InvestigationError(
            f'Total preview quota reached ({total}/'
            f'{constants.MAX_INVESTIGATIONS_TOTAL} investigations).'
        )

    # Warn when one away from either cap.
    if (today_count >= constants.MAX_INVESTIGATIONS_PER_DAY - 1
            or total >= constants.MAX_INVESTIGATIONS_TOTAL - 1):
        print(
            f'WARNING: approaching preview quota '
            f'(today: {today_count}/{constants.MAX_INVESTIGATIONS_PER_DAY}, '
            f'total: {total}/{constants.MAX_INVESTIGATIONS_TOTAL}).'
        )
        if not assume_yes:
            response = input('Continue and create another investigation? [y/N]: ')
            if response.strip().lower() not in ('y', 'yes'):
                raise InvestigationError('Aborted by user.')


def _start_date(summary: Dict):
    '''Best-effort extraction of an investigation's start date as a date object.'''
    start = summary.get('StartTime')
    if start is None:
        return None
    if isinstance(start, datetime):
        return start.astimezone(timezone.utc).date()
    # Epoch seconds (float) returned by some SDK serializations.
    try:
        return datetime.fromtimestamp(float(start), tz=timezone.utc).date()
    except (TypeError, ValueError, OSError):
        return None


def create(gd_client, detector_id: str, trigger_prompt: str) -> str:
    '''Create an investigation and return its id. Translates common errors.'''
    try:
        response = gd_client.create_investigation(
            DetectorId=detector_id,
            TriggerPrompt=trigger_prompt,
            ClientToken=_client_token(detector_id, trigger_prompt),
        )
    except ClientError as err:
        code = err.response.get('Error', {}).get('Code', '')
        if code in ('AccessDeniedException', 'AccessDenied'):
            raise InvestigationError(
                'Access denied creating an investigation. Only administrator or '
                'standalone accounts may create investigations; member accounts '
                'can only get/list their own.'
            ) from err
        raise InvestigationError(f'Failed to create investigation: {err}') from err

    return response['InvestigationId']


def get(gd_client, detector_id: str, investigation_id: str) -> Dict:
    '''Fetch a single investigation's full details.'''
    return gd_client.get_investigation(
        DetectorId=detector_id,
        InvestigationId=investigation_id,
    )['Investigation']


def poll_until_terminal(
    gd_client,
    detector_id: str,
    investigation_id: str,
    timeout: int = constants.DEFAULT_POLL_TIMEOUT_SECONDS,
    interval: int = constants.DEFAULT_POLL_INTERVAL_SECONDS,
) -> Dict:
    '''Poll GetInvestigation until COMPLETED/FAILED or the timeout elapses.'''
    deadline = time.monotonic() + timeout
    while True:
        investigation = get(gd_client, detector_id, investigation_id)
        status = investigation.get('Status')
        if status in constants.TERMINAL_STATUSES:
            return investigation
        if time.monotonic() >= deadline:
            print(
                f'Investigation {investigation_id} still {status} after '
                f'{timeout}s; returning latest state.'
            )
            return investigation
        print(f'  ...investigation {investigation_id} is {status}, waiting {interval}s')
        time.sleep(interval)


def _list_all_summaries(gd_client, detector_id: str) -> List[Dict]:
    '''Paginate through every investigation summary for the detector.'''
    summaries: List[Dict] = []
    next_token = None
    while True:
        kwargs = {'DetectorId': detector_id, 'MaxResults': 50}
        if next_token:
            kwargs['NextToken'] = next_token
        response = gd_client.list_investigations(**kwargs)
        summaries.extend(response.get('Investigations', []))
        next_token = response.get('NextToken')
        if not next_token:
            return summaries


def list_investigations(
    gd_client,
    detector_id: str,
    sort_attribute: Optional[str] = None,
    sort_order: str = 'DESC',
    max_results: Optional[int] = None,
) -> List[Dict]:
    '''List investigation summaries, optionally sorted, optionally capped.'''
    kwargs: Dict = {'DetectorId': detector_id, 'MaxResults': min(max_results or 50, 50)}
    if sort_attribute:
        if sort_attribute not in constants.SORT_ATTRIBUTES:
            raise InvestigationError(f'Invalid sort attribute: {sort_attribute}')
        if sort_order not in constants.SORT_ORDERS:
            raise InvestigationError(f'Invalid sort order: {sort_order}')
        kwargs['SortCriteria'] = {
            'AttributeName': sort_attribute,
            'OrderBy': sort_order,
        }

    summaries: List[Dict] = []
    next_token = None
    while True:
        if next_token:
            kwargs['NextToken'] = next_token
        response = gd_client.list_investigations(**kwargs)
        summaries.extend(response.get('Investigations', []))
        next_token = response.get('NextToken')
        if not next_token or (max_results and len(summaries) >= max_results):
            break

    return summaries[:max_results] if max_results else summaries
