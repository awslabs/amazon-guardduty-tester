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
Account and organization analysis.
Account analysis requires the caller to be the administrator of (or be) the
target account. Organization analysis sweeps signals across the org (<=100
accounts in preview).
'''

from typing import Dict, Optional

from core import investigator
from modes import run_investigation


def run_account(
    gd_client,
    detector_id: str,
    account_id: str,
    assume_yes: bool,
    wait: bool = True,
    poll_timeout: int = None,
    as_json: bool = False,
) -> Optional[Dict]:
    '''Analyze the threat posture of a single account.'''
    prompt = investigator.build_trigger_prompt('account', account_id)
    return run_investigation(
        gd_client, detector_id, prompt, assume_yes,
        wait=wait, poll_timeout=poll_timeout, as_json=as_json,
    )


def run_org(
    gd_client,
    detector_id: str,
    assume_yes: bool,
    wait: bool = True,
    poll_timeout: int = None,
    as_json: bool = False,
) -> Optional[Dict]:
    '''Analyze the threat posture across the organization.'''
    prompt = investigator.build_trigger_prompt('org')
    return run_investigation(
        gd_client, detector_id, prompt, assume_yes,
        wait=wait, poll_timeout=poll_timeout, as_json=as_json,
    )
