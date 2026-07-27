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
Finding analysis: investigate a single GuardDuty finding by its 32-char id.
'''

from typing import Dict, Optional

from core import investigator
from modes import run_investigation


def run(
    gd_client,
    detector_id: str,
    finding_id: str,
    assume_yes: bool,
    wait: bool = True,
    poll_timeout: int = None,
    as_json: bool = False,
) -> Optional[Dict]:
    '''Investigate one finding id.'''
    prompt = investigator.build_trigger_prompt('finding', finding_id)
    return run_investigation(
        gd_client, detector_id, prompt, assume_yes,
        wait=wait, poll_timeout=poll_timeout, as_json=as_json,
    )
