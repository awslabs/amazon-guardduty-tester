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
Rendering of investigation results for the terminal (or raw JSON).
The GuardDuty `summary` field is itself a JSON string holding key observations,
countermeasures, and a MITRE ATT&CK threat assessment.
'''

import json
from typing import Dict, List

from core import constants, guide

_BAR = '*' * 71


def _annotate(level, meanings: Dict) -> str:
    '''Append the meaning of a risk/confidence level inline, e.g. "Critical (severe ...)".'''
    if not level:
        return '-'
    desc = meanings.get(str(level).lower())
    return f'{level} ({desc})' if desc else str(level)


def parse_summary(summary_str) -> Dict:
    '''Defensively parse the summary JSON string into a dict.'''
    if not summary_str:
        return {}
    if isinstance(summary_str, dict):
        return summary_str
    try:
        return json.loads(summary_str)
    except (ValueError, TypeError):
        # Not JSON (or an unexpected shape) -> expose it as a plain narrative.
        return {'narrative': str(summary_str)}


def render(investigation: Dict, as_json: bool = False) -> str:
    '''Render a completed (or terminal) investigation as text or JSON.'''
    if as_json:
        return json.dumps(investigation, indent=2, default=str)

    lines: List[str] = []
    lines.append(_BAR)
    lines.append('GuardDuty Investigation')
    lines.append(_BAR)
    lines.append(f"Investigation ID : {investigation.get('InvestigationId', '-')}")
    lines.append(f"Status           : {investigation.get('Status', '-')}")
    lines.append(f"Trigger Prompt   : {investigation.get('TriggerPrompt', '-')}")
    lines.append(f"Risk Level       : {_annotate(investigation.get('RiskLevel'), guide.RISK_MEANINGS)}")
    lines.append(f"Confidence       : {_annotate(investigation.get('Confidence'), guide.CONFIDENCE_MEANINGS)}")

    risk = investigation.get('Risk')
    if risk:
        lines.append(f"Risk             : {risk}")

    cloud = investigation.get('Cloud') or {}
    if cloud:
        lines.append(
            f"Account / Region : {cloud.get('Account', '-')} / {cloud.get('Region', '-')}"
        )

    error = investigation.get('Error')
    if error:
        lines.append(f"Error            : {error}")

    metadata = investigation.get('Metadata') or {}
    if metadata:
        product = (metadata.get('Product') or {})
        product_name = product.get('Name')
        version = metadata.get('Version')
        meta_bits = [b for b in (product_name, f'v{version}' if version else None) if b]
        if meta_bits:
            lines.append(f"Product          : {' '.join(meta_bits)}")

    # Render the summary for any terminal investigation that carries one.
    summary = parse_summary(investigation.get('Summary'))
    if summary:
        lines.extend(_render_summary(summary))

    lines.append('')
    lines.append(_BAR)
    lines.append(constants.HUMAN_REVIEW_CAVEAT)
    lines.append(_BAR)
    return '\n'.join(lines)


# Summary keys this renderer formats explicitly; everything else is dumped
# generically so the output is never lossy regardless of the payload shape.
_HANDLED_SUMMARY_KEYS = {
    'keyObservations', 'observations', 'narrative',
    'threatAssessment', 'countermeasures',
}


def _render_summary(summary: Dict) -> List[str]:
    '''Render the summary structure, never silently dropping unrecognized keys.'''
    lines: List[str] = []

    key_obs = summary.get('keyObservations') or {}
    if key_obs:
        lines.append('')
        title = key_obs.get('title')
        if title:
            lines.append(f'Key Observations: {title}')
        narrative = key_obs.get('narrative')
        if narrative:
            lines.append(f'  {narrative}')
        for obs in key_obs.get('observations', []) or []:
            lines.append(f'  - {_as_text(obs)}')

    # Observations may also appear as a top-level list (not nested in keyObservations).
    top_obs = summary.get('observations')
    if top_obs and not key_obs:
        lines.append('')
        lines.append('Observations:')
        for obs in top_obs if isinstance(top_obs, list) else [top_obs]:
            lines.append(f'  - {_as_text(obs)}')

    # Some payloads put a bare narrative at the top level (non-JSON fallback).
    if 'narrative' in summary and 'keyObservations' not in summary:
        lines.append('')
        lines.append('Summary:')
        lines.append(f"  {summary['narrative']}")

    assessment = summary.get('threatAssessment') or {}
    if assessment:
        lines.append('')
        lines.append('Threat Assessment (MITRE ATT&CK):')
        for technique in assessment.get('techniques', []) or []:
            lines.append(f'  - {_as_text(technique)}')
        for key, value in assessment.items():
            if key == 'techniques':
                continue
            lines.append(f'  {key}: {_as_text(value)}')

    countermeasures = summary.get('countermeasures') or []
    if countermeasures:
        lines.append('')
        lines.append('Recommended Actions:')
        for i, item in enumerate(countermeasures, start=1):
            lines.extend(_render_countermeasure(i, item))

    # Catch-all: render any summary fields not handled above so nothing is lost.
    extra = {k: v for k, v in summary.items()
             if k not in _HANDLED_SUMMARY_KEYS and v not in (None, '', [], {})}
    if extra:
        lines.append('')
        lines.append('Additional Details:')
        for key, value in extra.items():
            lines.extend(_render_field(key, value))

    return lines


def _render_field(key: str, value, indent: str = '  ') -> List[str]:
    '''Render an arbitrary key/value, expanding dicts and lists readably.'''
    if isinstance(value, dict):
        lines = [f'{indent}{key}:']
        for sub_key, sub_value in value.items():
            lines.extend(_render_field(sub_key, sub_value, indent + '  '))
        return lines
    if isinstance(value, list):
        lines = [f'{indent}{key}:']
        for item in value:
            lines.append(f'{indent}  - {_as_text(item)}')
        return lines
    return [f'{indent}{key}: {_as_text(value)}']


def _render_countermeasure(index: int, item) -> List[str]:
    '''Render a single recommended action, surfacing any CLI command.'''
    if not isinstance(item, dict):
        return [f'  {index}. {_as_text(item)}']

    lines: List[str] = []
    description = item.get('description') or item.get('title') or _as_text(item)
    lines.append(f'  {index}. {description}')
    command = item.get('command') or item.get('cliCommand')
    if command:
        lines.append(f'       $ {command}')
    return lines


def _as_text(value) -> str:
    '''Coerce a value (possibly a dict/list) into a readable single line.'''
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        for key in ('description', 'title', 'text', 'name'):
            if key in value:
                return str(value[key])
        return json.dumps(value, default=str)
    if isinstance(value, list):
        return ', '.join(_as_text(v) for v in value)
    return str(value)


def render_summary_table(summaries: List[Dict]) -> str:
    '''Render a compact table of investigation summaries (for `list`).'''
    if not summaries:
        return 'No investigations found.'

    header = f"{'INVESTIGATION ID':38} {'STATUS':10} {'RISK':9} {'CONF':8} TRIGGER"
    lines = [header, '-' * len(header)]
    for s in summaries:
        lines.append(
            f"{s.get('InvestigationId', '-'):38} "
            f"{s.get('Status', '-'):10} "
            f"{s.get('RiskLevel', '-'):9} "
            f"{s.get('Confidence', '-'):8} "
            f"{(s.get('TriggerPrompt') or '')[:60]}"
        )
    return '\n'.join(lines)
