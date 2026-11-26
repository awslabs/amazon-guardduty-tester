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
Distribution of Custom Detection Rule tests across the static test hosts.

Tests that share a name prefix (for example the three FindCommandRecon* tests, or
the five FirewallConfigModified* tests) exercise closely related files and
commands, so they are spread over different hosts. The prefix is the first
PREFIX_WORDS CamelCase words of the test id.

The assignment is a pure function of the test ids and the host count: the same
inputs always give the same result, so a test always runs on the same host. The
runner computes it over the whole catalog for an OS and then keeps only the
selected tests, so selecting a subset never moves a test to another host.

When a prefix group has more tests than there are hosts, the group cannot be
fully separated; it is spread as evenly as possible instead (with 3 hosts, a
group of 6 puts 2 tests on each host).
'''

import re
from typing import Dict, List

from .cdr_config import PREFIX_WORDS

# A word is a Capitalised word ("Find"), or a run of capitals not followed by a
# lowercase letter ("SSH" in "SSHAuthorized", "LD" in "LDPreload").
_WORD = re.compile(r'[A-Z][a-z0-9]+|[A-Z]+(?![a-z])|[0-9]+')


def prefix_key(test_id: str, words: int = PREFIX_WORDS) -> str:
    '''Return the common-prefix key of a test id, e.g. FindCommandReconKeyMaterial -> FindCommand.'''
    parts = _WORD.findall(test_id)
    return ''.join(parts[:words]) or test_id


def assign(test_ids: List[str], host_count: int) -> Dict[str, int]:
    '''
    Map each test id to a host index in range(host_count).

    Prefix groups are placed largest first. Each test goes to the host that holds
    the fewest tests of its own prefix group, then the fewest tests overall, then
    the lowest index. That keeps same-prefix tests apart and the hosts balanced,
    and it is deterministic.
    '''
    if host_count < 1:
        raise ValueError('host_count must be at least 1')

    groups: Dict[str, List[str]] = {}
    for test_id in test_ids:
        groups.setdefault(prefix_key(test_id), []).append(test_id)

    totals = [0] * host_count
    assignment: Dict[str, int] = {}
    for key in sorted(groups, key=lambda k: (-len(groups[k]), k)):
        in_group = [0] * host_count
        for test_id in groups[key]:
            host = min(range(host_count), key=lambda h: (in_group[h], totals[h], h))
            assignment[test_id] = host
            in_group[host] += 1
            totals[host] += 1
    return assignment
