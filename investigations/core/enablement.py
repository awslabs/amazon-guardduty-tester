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
Region guard, detector resolution, and AI_ANALYST feature enablement.
The investigations tooling owns its own enablement so it stays independent
of the tester's settings_manager.
'''

from typing import List, Optional

from core import constants


class InvestigationError(Exception):
    '''Raised for user-facing investigation errors (bad region, missing detector, etc).'''


def assert_supported_region(region: str) -> None:
    '''Raise if the region is not one of the 10 preview regions.'''
    if region not in constants.SUPPORTED_REGIONS:
        supported = ', '.join(sorted(constants.SUPPORTED_REGIONS))
        raise InvestigationError(
            f"GuardDuty Investigation is not available in '{region}'.\n"
            f'During preview it is available only in: {supported}'
        )


def resolve_detector_id(gd_client, explicit: Optional[str] = None) -> str:
    '''Return the given detector id, or look up the single detector in the region.'''
    if explicit:
        return explicit

    detector_ids: List[str] = gd_client.list_detectors().get('DetectorIds', [])
    if not detector_ids:
        raise InvestigationError(
            'No GuardDuty detector found in this region. Enable GuardDuty first, '
            'or pass --detector-id explicitly.'
        )
    if len(detector_ids) > 1:
        joined = ', '.join(detector_ids)
        raise InvestigationError(
            f'Multiple detectors found ({joined}). Pass --detector-id to choose one.'
        )
    return detector_ids[0]


def is_ai_analyst_enabled(gd_client, detector_id: str) -> bool:
    '''Check whether the AI_ANALYST feature is ENABLED on the detector.'''
    detector = gd_client.get_detector(DetectorId=detector_id)
    for feature in detector.get('Features', []):
        if feature.get('Name') == constants.AI_ANALYST_FEATURE:
            return feature.get('Status') == 'ENABLED'
    return False


def _confirm(prompt: str, assume_yes: bool) -> bool:
    '''Prompt the user for a yes/no confirmation unless assume_yes is set.'''
    if assume_yes:
        return True
    response = input(f'{prompt} [y/N]: ').strip().lower()
    return response in ('y', 'yes')


def ensure_ai_analyst_enabled(gd_client, detector_id: str, assume_yes: bool) -> None:
    '''
    Ensure AI_ANALYST is enabled, enabling it (with confirmation) if needed.
    The user is asked to confirm before any change unless assume_yes is set.
    '''
    if is_ai_analyst_enabled(gd_client, detector_id):
        return

    print()
    print('The AI_ANALYST feature is required for GuardDuty Investigation but is')
    print('not currently enabled on this detector.')
    print()

    if not _confirm(f'Enable AI_ANALYST on detector {detector_id}?', assume_yes):
        raise InvestigationError(
            'AI_ANALYST not enabled. Cannot create investigations without it.'
        )

    gd_client.update_detector(
        DetectorId=detector_id,
        Features=[{'Name': constants.AI_ANALYST_FEATURE, 'Status': 'ENABLED'}],
    )
    print(f'Enabled AI_ANALYST on detector {detector_id}.')
