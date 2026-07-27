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
Shared orchestration for investigation modes.
Every mode reduces to: ensure prerequisites -> build prompt -> create ->
(optionally) poll -> report.
'''

from typing import Dict, Optional

from core import investigator, report
from core.enablement import ensure_ai_analyst_enabled


def run_investigation(
    gd_client,
    detector_id: str,
    trigger_prompt: str,
    assume_yes: bool,
    wait: bool = True,
    poll_timeout: int = None,
    as_json: bool = False,
) -> Optional[Dict]:
    '''
    Create an investigation from a prepared trigger prompt and report results.
    Assumes the region has already been validated by the caller.
    Returns the terminal investigation dict (or None when --no-wait).
    '''
    ensure_ai_analyst_enabled(gd_client, detector_id, assume_yes)
    investigator.check_quota(gd_client, detector_id, assume_yes)

    print(f'Creating investigation: "{trigger_prompt}"')
    investigation_id = investigator.create(gd_client, detector_id, trigger_prompt)
    print(f'Created investigation {investigation_id}')

    if not wait:
        print('Run `get` later to retrieve results once it completes.')
        return None

    kwargs = {}
    if poll_timeout is not None:
        kwargs['timeout'] = poll_timeout
    investigation = investigator.poll_until_terminal(
        gd_client, detector_id, investigation_id, **kwargs
    )
    print()
    print(report.render(investigation, as_json=as_json))
    return investigation
