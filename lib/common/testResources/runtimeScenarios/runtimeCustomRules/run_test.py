#!/usr/bin/env python3
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
Single entry point for the runtime Custom Detection Rule (CDR) scenarios.

Usage:
  ./run_test.py --custom-rule <TestId|RuleId> [<TestId|RuleId> ...]
  ./run_test.py --all
  ./run_test.py --custom-rule FirewallConfigModified --os ubuntu2204   # force one OS

A token passed to --custom-rule is a testId (runs that one test) or a ruleId
(runs every test of that rule). --all runs the entire catalog. --custom-rule and
--all are mutually exclusive; exactly one is required.

The tests run on static hosts that the CDK stack creates: several Amazon Linux 2023
instances (CDR_HOST_COUNT in lib/stacks/constants.ts) and the existing Ubuntu instance. The harness finds them by tag/name.
Tests are spread over the Amazon Linux hosts so that tests with a common prefix
(for example the FindCommandRecon* tests) run on different hosts; see
custom_detection_rules/distribution.py. Hosts run in parallel; the tests on one
host run one after another.

Target OS: by default each selected test runs on the OS it is in scope for --
Amazon Linux 2023 for almost every test, and the Ubuntu host for the one test
excluded from AL2023 (DnsTunnelingToolExecuted, whose tools are not in the AL2023
repos). Passing --os forces the whole run onto one OS instead (tests out of scope
for it are reported as skipped).

The user is responsible for ensuring each rule is associated and LIVE in
GuardDuty before running.
'''

import argparse
import os
import sys

# This folder (so the custom_detection_rules package imports). The catalog,
# runner, config and ops all live inside that package; only this entry point and
# the README sit at the top level of runtimeCustomRules/.
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# The driver host lays the tester down at /home/ssm-user/py_tester, where
# tester_vars.py is generated. Add that (the testResources root is three levels
# up from this folder) plus the conventional absolute path, mirroring the other
# scenario scripts, so `import tester_vars` resolves on the driver.
sys.path.append('/home/ssm-user/py_tester')
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(HERE))))

from custom_detection_rules.catalog import (
    OS_NAME_BY_SLUG,
    SCOPE_IN,
    CustomDetectionRuleCatalog,
)
from custom_detection_rules.runner import ScenarioRunner
from custom_detection_rules import cdr_config as cfg

# OS slugs the harness tries, in order, when deriving a test's target OS. AL2023
# is the default; a test excluded from AL2023 (e.g. DnsTunnelingToolExecuted)
# falls through to the next slug it is in scope for.
OS_PREFERENCE = ('al2023', 'ubuntu2204')

PLATFORM = 'ec2'


def _derive_os(catalog: CustomDetectionRuleCatalog, test_id: str):
    '''
    Pick the OS a test should run on: the first OS in OS_PREFERENCE for which the
    test is in scope on the ec2 platform. Returns None if the test is in scope
    for none of them (it will be reported as skipped by the caller).
    '''
    for os_slug in OS_PREFERENCE:
        status, _ = catalog.scope_status(test_id, PLATFORM, os_slug)
        if status == SCOPE_IN:
            return os_slug
    return None


def _parse_args(argv):
    parser = argparse.ArgumentParser(
        prog='run_test.py',
        description='Run runtime GuardDuty Custom Detection Rule test(s) on the '
                    'static test hosts.')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        '--custom-rule', nargs='+', metavar='ID', dest='custom_rule',
        help='One or more test ids (e.g. FirewallConfigModifiedUfwDefault) or '
             'rule ids (e.g. FirewallConfigModified, which runs all of that '
             "rule's tests).")
    group.add_argument(
        '--all', action='store_true',
        help='Run every test in the catalog.')
    parser.add_argument(
        '--os', dest='os_slug', choices=['al2023', 'ubuntu2204'],
        default=None,
        help='Force the whole run onto this OS instead of deriving each test\'s '
             'OS from the catalog scope. Tests out of scope for it are skipped.')
    return parser.parse_args(argv)


def run(argv=None) -> int:
    args = _parse_args(sys.argv[1:] if argv is None else argv)

    # Imported lazily so arg parsing / help do not require boto3 to be present.
    from custom_detection_rules.static_host_ops import StaticHostOps

    catalog = CustomDetectionRuleCatalog.load()
    runner = ScenarioRunner(catalog)

    # Resolve the selection to concrete test ids.
    if args.all:
        selectors = catalog.test_ids()
    else:
        selectors = args.custom_rule
    matched, unknown = catalog.select(selectors)
    for token in unknown:
        print(f'[cdr] unknown test/rule, skipping: {token}')
    if not matched:
        print('[cdr] no known tests selected; nothing to do')
        return 1

    # Group the selected tests by the OS they will run on.
    groups = {}          # os_slug -> list of testIds
    skipped_no_os = []
    for test in matched:
        test_id = test['testId']
        if args.os_slug:
            os_slug = args.os_slug         # forced: let the runner scope/skip it
        else:
            os_slug = _derive_os(catalog, test_id)
            if os_slug is None:
                skipped_no_os.append(test_id)
                continue
        groups.setdefault(os_slug, []).append(test_id)

    for test_id in skipped_no_os:
        print(f'[cdr] {test_id}: not in scope on any supported OS, skipping')

    ops = StaticHostOps()
    hosts = ops.find_hosts()
    for os_name, found in sorted(hosts.items()):
        print(f'[cdr] {os_name} hosts: {[h.name for h in found] or "none running"}')

    ran = failed = skipped = 0
    for os_slug, test_ids in sorted(groups.items()):
        os_name = OS_NAME_BY_SLUG[os_slug]
        print(f'[cdr] running {len(test_ids)} test(s) on {os_slug} ({len(hosts.get(os_name, []))} host(s))')
        outcomes = runner.run_on_hosts(
            test_ids,
            os_slug,
            hosts.get(os_name, []),
            ops=ops,
            interval_seconds=cfg.CDR_TEST_INTERVAL_SECONDS,
            final_settle_seconds=cfg.CDR_FINAL_SETTLE_SECONDS,
        )
        for outcome in outcomes:
            if outcome.action == 'ran':
                ran += 1
            elif outcome.action == 'failed':
                failed += 1
                print(f'[cdr] FAILED: {outcome.test_id}: {outcome.detail}')
            else:
                skipped += 1

    print(f'[cdr] done: {ran} ran, {failed} failed, {skipped + len(skipped_no_os)} skipped')
    return 0 if ran > 0 and failed == 0 else 1


if __name__ == '__main__':
    sys.exit(run())
