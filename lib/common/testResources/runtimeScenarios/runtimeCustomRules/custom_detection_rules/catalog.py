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
Loader for the runtime GuardDuty Custom Detection Rule catalog
(custom_detection_rules.json). This is a SEPARATE path from the
definitions.json flow used by test_builder.py.

The catalog has two sections. `rules` maps each GuardDuty custom detection rule
(ruleId) to the finding type its benign trigger is expected to produce. `tests`
are the executable unit: each test names the rule it exercises (ruleId), a
benign trigger script, and the packages that trigger needs. One rule may have
several tests (e.g. one per watched path). Scope exclusions key by testId.

The module is intentionally free of any tester_vars / deployment-time
dependency so the catalog can be loaded and inspected locally without a
deployed stack.
'''

import json
import os
from typing import Dict, List, Optional, Tuple

CATALOG_FILENAME = 'custom_detection_rules.json'

# Scope status values returned by scope_status().
SCOPE_IN = 'in'
SCOPE_OUT = 'out'

# OS name -> the slug used as a key in the catalog `scope` section.
OS_SCOPE_SLUGS = {'amazonlinux': 'al2023', 'ubuntu': 'ubuntu2204'}

# Inverse: scope OS slug -> OS name used by the ops layer (AMI/tag resolution).
OS_NAME_BY_SLUG = {slug: name for name, slug in OS_SCOPE_SLUGS.items()}

class CustomDetectionRuleCatalog:
    '''
    Thin wrapper around custom_detection_rules.json providing lookup and
    filtering by test id / rule id. The unit of execution and scope is the
    test; the rule carries shared metadata.
    '''

    def __init__(self, document: dict) -> None:
        self.document = document
        # rule metadata keyed by ruleId.
        self._rules: Dict[str, dict] = {r['ruleId']: r for r in document.get('rules', [])}
        # Enriched test entries: each test dict merged with its rule's finding
        # type so downstream code has everything it needs on one object.
        self.tests: List[dict] = []
        self._test_index: Dict[str, dict] = {}       # testId (lower) -> entry
        self._tests_by_rule: Dict[str, List[dict]] = {}
        for test in document.get('tests', []):
            rule = self._rules.get(test.get('ruleId'), {})
            entry = {
                'testId': test['testId'],
                'ruleId': test['ruleId'],
                'trigger': test.get('trigger'),
                'packages': test.get('packages', []),
                'findingType': rule.get('findingType', ''),
            }
            self.tests.append(entry)
            self._test_index[entry['testId'].lower()] = entry
            self._tests_by_rule.setdefault(entry['ruleId'], []).append(entry)
        self.scope: dict = document.get('scope', {})
        self._validate_scope()

    def _validate_scope(self) -> None:
        '''Fail fast on a scope entry naming a test that is not in the catalog.'''
        known = {t['testId'] for t in self.tests}
        named: List[str] = []
        for dimension in ('computeTypes', 'osTypes'):
            for leaf in (self.scope.get(dimension) or {}).values():
                if isinstance(leaf, dict):
                    named.extend((leaf.get('ruleExclusions') or {}).keys())
        unknown = sorted(set(named) - known)
        if unknown:
            raise ValueError(f'catalog scope names unknown test(s): {", ".join(unknown)}')

    def scope_status(self, test_id: str, platform: str, os_slug: str) -> Tuple[str, str]:
        '''
        Return (status, reason) for a test on a compute platform / OS, where
        status is SCOPE_IN or SCOPE_OUT. Scope is the intersection of two
        independent dimensions: a test is SCOPE_IN unless the compute platform
        excludes it OR the OS excludes it (the platform reason wins if both do).
        A platform or OS missing from the scope section is SCOPE_OUT. reason is
        empty for SCOPE_IN.
        '''
        compute_leaf = (self.scope.get('computeTypes') or {}).get(platform)
        os_leaf = (self.scope.get('osTypes') or {}).get(os_slug)
        if compute_leaf is None or os_leaf is None:
            return SCOPE_OUT, 'not defined in the scope section for this compute type/OS'
        compute_exclusions = compute_leaf.get('ruleExclusions') or {}
        if test_id in compute_exclusions:
            return SCOPE_OUT, compute_exclusions[test_id]
        os_exclusions = os_leaf.get('ruleExclusions') or {}
        if test_id in os_exclusions:
            return SCOPE_OUT, os_exclusions[test_id]
        return SCOPE_IN, ''

    @classmethod
    def default_path(cls) -> str:
        # The catalog JSON lives inside this package, next to this module.
        base = os.path.dirname(os.path.abspath(__file__))
        return os.path.join(base, CATALOG_FILENAME)

    @classmethod
    def load(cls, path: Optional[str] = None) -> 'CustomDetectionRuleCatalog':
        path = path or cls.default_path()
        with open(path) as f:
            return cls(json.load(f))

    # --- tests (the execution unit) ---------------------------------------

    def all_tests(self) -> List[dict]:
        return list(self.tests)

    def test_ids(self) -> List[str]:
        return [t['testId'] for t in self.tests]

    def get(self, test_id: str) -> Optional[dict]:
        '''Look up a single test by testId (case-insensitive).'''
        if not test_id:
            return None
        return self._test_index.get(test_id.lower())

    def tests_for_rule(self, rule_id: str) -> List[dict]:
        return list(self._tests_by_rule.get(rule_id, []))

    def select(self, tokens: List[str]) -> Tuple[List[dict], List[str]]:
        '''
        Resolve a list of tokens to test entries, preserving order and
        de-duplicating. A token may be a testId (selects that one test) or a
        ruleId (expands to every test of that rule). Returns (matched, unknown).
        '''
        matched: List[dict] = []
        unknown: List[str] = []
        seen: set = set()

        def _add(entry: dict) -> None:
            if entry['testId'] not in seen:
                matched.append(entry)
                seen.add(entry['testId'])

        for token in tokens:
            if not token:
                continue
            key = token.lower()
            entry = self._test_index.get(key)
            if entry is not None:
                _add(entry)
                continue
            rule_tests = [e for e in self.tests if e['ruleId'].lower() == key]
            if rule_tests:
                for e in rule_tests:
                    _add(e)
            else:
                unknown.append(token)
        return matched, unknown

    # --- rules (metadata) -------------------------------------------------

    def all_rules(self) -> List[dict]:
        return list(self._rules.values())

    def rule_ids(self) -> List[str]:
        return list(self._rules.keys())

    def get_rule(self, rule_id: str) -> Optional[dict]:
        return self._rules.get(rule_id)
