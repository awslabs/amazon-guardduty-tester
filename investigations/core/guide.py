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
Prompt-library rendering (the `prompts` command) and the risk/confidence
scales, which report.py uses to annotate live results.
'''

from typing import Dict, Optional

from core import prompts
from core.enablement import InvestigationError

# Ordered low->high. Used to annotate live get/finding output.
RISK_LEVELS = [
    ('Info', 'Informational; no immediate risk to the environment.'),
    ('Low', 'Minor risk that is unlikely to require immediate action.'),
    ('Medium', 'Moderate risk to review; may require remediation.'),
    ('High', 'Significant risk requiring prompt investigation and remediation.'),
    ('Critical', 'Severe risk requiring immediate action to prevent further compromise.'),
]

CONFIDENCE_LEVELS = [
    ('Unknown', 'Insufficient data to determine confidence in the assessment.'),
    ('Low', 'Limited evidence supports the assessment; corroborate before acting.'),
    ('Medium', 'Moderate evidence supports the assessment.'),
    ('High', 'Strong evidence supports the assessment.'),
]

# Lookup maps for inline annotation (case-insensitive on the level name).
RISK_MEANINGS = {name.lower(): desc for name, desc in RISK_LEVELS}
CONFIDENCE_MEANINGS = {name.lower(): desc for name, desc in CONFIDENCE_LEVELS}

_BAR = '*' * 71


def render_prompts(
    search: Optional[str] = None,
    prompt_id: Optional[str] = None,
) -> str:
    '''Render the prompt library: one full entry (by id) or a listing.'''
    library = prompts.load_library()

    if prompt_id:
        match = next((p for p in library if p.get('id') == prompt_id), None)
        if not match:
            raise InvestigationError(f'No prompt with id "{prompt_id}".')
        return _render_entry_full(match)

    selected = prompts.filter_prompts(library, search)
    if not selected:
        return 'No prompts matched. Try `prompts` with no filters to see all.'

    lines = ['Trigger-prompt library', _BAR]
    for p in selected:
        lines.append(f"\n  {p['id']}")
        lines.append(f"    {p['title']}")
        lines.append(f"    $ {p['prompt']}")
    lines.append('')
    lines.append('Show one entry: gd_investigator.py prompts --id <id>')
    lines.append('Contribute a prompt: see the Prompts section of investigations/README.md')
    return '\n'.join(lines)


def _render_entry_full(entry: Dict) -> str:
    lines = [_BAR, f"{entry['id']}", _BAR]
    lines.append(f"Title    : {entry.get('title', '-')}")
    lines.append(f"Prompt   : {entry.get('prompt', '-')}")
    if entry.get('notes'):
        lines.append(f"Notes    : {entry['notes']}")
    if entry.get('contributedBy'):
        lines.append(f"By       : {entry['contributedBy']}")
    return '\n'.join(lines)
