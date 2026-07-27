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
Load, validate, and render the trigger-prompt library (prompts/library.json).
The library is a contribution target, so loading also validates entries and
reports problems clearly.
'''

import os
import re
import json
from typing import Dict, List, Optional

from core import constants
from core.enablement import InvestigationError

# prompts/library.json lives one directory up from this file's package.
_LIBRARY_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'prompts', 'library.json',
)

REQUIRED_FIELDS = ('id', 'title', 'prompt')
_ID_PATTERN = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$')


def load_library(path: str = _LIBRARY_PATH) -> List[Dict]:
    '''Load and validate the prompt library. Raises InvestigationError on problems.'''
    try:
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError as err:
        raise InvestigationError(f'Prompt library not found at {path}') from err
    except json.JSONDecodeError as err:
        raise InvestigationError(f'Prompt library is not valid JSON: {err}') from err

    prompts = data.get('prompts')
    if not isinstance(prompts, list):
        raise InvestigationError('Prompt library must have a "prompts" array.')

    errors = validate(prompts)
    if errors:
        raise InvestigationError(
            'Prompt library has invalid entries:\n  - ' + '\n  - '.join(errors)
        )
    return prompts


def validate(prompts: List[Dict]) -> List[str]:
    '''Return a list of human-readable problems (empty list = valid).'''
    errors: List[str] = []
    seen_ids = set()

    for i, entry in enumerate(prompts):
        label = entry.get('id') or f'entry #{i}'

        for field in REQUIRED_FIELDS:
            if not entry.get(field):
                errors.append(f'{label}: missing required field "{field}"')

        entry_id = entry.get('id', '')
        if entry_id:
            if not _ID_PATTERN.match(entry_id):
                errors.append(f'{label}: id is not kebab-case')
            if entry_id in seen_ids:
                errors.append(f'{label}: duplicate id')
            seen_ids.add(entry_id)

        prompt = entry.get('prompt', '')
        if prompt and len(prompt) > constants.MAX_TRIGGER_PROMPT_LEN:
            errors.append(f'{label}: prompt exceeds {constants.MAX_TRIGGER_PROMPT_LEN} chars')

    return errors


def filter_prompts(
    prompts: List[Dict],
    search: Optional[str] = None,
) -> List[Dict]:
    '''Filter prompts by free-text search.'''
    result = prompts
    if search:
        needle = search.lower()
        result = [
            p for p in result
            if needle in p.get('title', '').lower()
            or needle in p.get('prompt', '').lower()
            or needle in p.get('notes', '').lower()
        ]
    return result
