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
Runtime custom detection rule scenario runner.

The unit of execution is a test (a benign trigger that exercises one rule in one
way). The runner ties together the catalog, the distribution of tests over the
static hosts, and the shared helpers (sibling modules in this package). It makes
no AWS calls itself: the caller injects an ops object (StaticHostOps) that talks
to SSM. With no ops object it runs in plan mode and only reports what would run
where, so the harness can be inspected without a deployed stack.

Tests run on static hosts created by the CDK stack. Hosts run in parallel; the
tests assigned to one host run one after another, so two tests never interfere on
the same host at the same time.
'''

import concurrent.futures
import os
import time
from typing import Dict, List, Optional

from .catalog import OS_NAME_BY_SLUG, SCOPE_IN, CustomDetectionRuleCatalog
from .context import build_package_install
from .distribution import assign


class Host:
    '''A static test host: its OS name (amazonlinux/ubuntu), Name tag and instance id.'''

    def __init__(self, os_name: str, name: str, instance_id: str) -> None:
        self.os_name = os_name
        self.name = name
        self.instance_id = instance_id


class RunOutcome:
    '''Per-test outcome record for reporting.'''

    def __init__(self, test_id: str, action: str, detail: str) -> None:
        self.test_id = test_id
        self.action = action  # 'ran', 'failed', 'built' (plan mode), 'skipped'
        self.detail = detail


class ScenarioRunner:

    def __init__(
        self,
        catalog: CustomDetectionRuleCatalog,
        scenarios_dir: Optional[str] = None,
    ) -> None:
        self.catalog = catalog
        # scenarios/ lives inside this package, next to this module.
        self.scenarios_dir = scenarios_dir or os.path.join(
            os.path.dirname(os.path.abspath(__file__)), 'scenarios')

    def _read_trigger(self, test: dict) -> str:
        path = os.path.join(self.scenarios_dir, test.get('trigger'))
        with open(path) as f:
            return f.read()

    def _select_survivors(self, matched: List[dict], platform: str, os_slug: str,
                          outcomes: List[RunOutcome]) -> List[dict]:
        '''Drop out-of-scope tests, recording skipped outcomes.'''
        survivors: List[dict] = []
        for test in matched:
            name = test['testId']
            status, reason = self.catalog.scope_status(name, platform, os_slug)
            if status != SCOPE_IN:
                print(f'[cdr] {name}: out of scope on {platform}/{os_slug} ({reason}), skipping')
                outcomes.append(RunOutcome(name, 'skipped', f'out of scope: {reason}'))
                continue
            survivors.append(test)
        return survivors

    def host_assignment(self, os_slug: str, host_count: int, platform: str = 'ec2') -> Dict[str, int]:
        '''
        Map every test that is in scope for the OS to a host index. Computed over
        the whole catalog, not just the selection, so a test always lands on the
        same host however many tests are selected.
        '''
        universe = [t['testId'] for t in self.catalog.all_tests()
                    if self.catalog.scope_status(t['testId'], platform, os_slug)[0] == SCOPE_IN]
        return assign(universe, host_count)

    def run_on_hosts(self, selectors: List[str], os_slug: str, hosts: List[Host], ops=None,
                     platform: str = 'ec2', interval_seconds: int = 30,
                     final_settle_seconds: int = 120) -> List[RunOutcome]:
        '''
        Run the selected tests on the static hosts for `os_slug`.

        Selection: tests in scope for (platform, os_slug) survive; the rest are
        reported as skipped. Each survivor is assigned to one of `hosts` by
        host_assignment. In a real run (ops given) every host that has tests is
        waited to SSM-online and the GuardDuty runtime agent active, then runs its
        tests in catalog order: best-effort package install plus the trigger, in
        one SSM command, with `interval_seconds` between tests. After its last
        test a host waits `final_settle_seconds` so the Runtime Monitoring sensor
        can ship its telemetry. A trigger that exits non-zero is reported as
        'failed'.

        With ops omitted the runner stays in plan mode: it runs nothing and only
        reports which test would run on which host.
        '''
        matched, unknown = self.catalog.select(selectors)
        for token in unknown:
            print(f'[cdr] unknown test/rule, skipping: {token}')
        if not matched:
            print('[cdr] no known tests selected; nothing to do')
            return []

        outcomes: List[RunOutcome] = []
        survivors = self._select_survivors(matched, platform, os_slug, outcomes)
        if not survivors:
            return outcomes
        if not hosts:
            for test in survivors:
                outcomes.append(RunOutcome(test['testId'], 'skipped',
                                           f'no running {OS_NAME_BY_SLUG[os_slug]} host'))
            return outcomes

        assignment = self.host_assignment(os_slug, len(hosts), platform)
        queues: Dict[int, List[dict]] = {}
        for test in survivors:
            queues.setdefault(assignment[test['testId']], []).append(test)

        if ops is None:
            for index in sorted(queues):
                for test in queues[index]:
                    print(f'[cdr] {test["testId"]}: would run on {hosts[index].name} (plan mode)')
                    outcomes.append(RunOutcome(test['testId'], 'built', 'plan mode'))
            return outcomes

        with concurrent.futures.ThreadPoolExecutor(max_workers=len(queues)) as pool:
            futures = {
                pool.submit(self._run_host, ops, hosts[index], queues[index],
                            interval_seconds, final_settle_seconds): index
                for index in queues
            }
            for future in concurrent.futures.as_completed(futures):
                outcomes.extend(future.result())
        return outcomes

    def _run_host(self, ops, host: Host, queue: List[dict], interval_seconds: int,
                  final_settle_seconds: int) -> List[RunOutcome]:
        '''Run one host's tests one after another and return their outcomes.'''
        outcomes: List[RunOutcome] = []
        print(f'[cdr] {host.name} ({host.instance_id}): {len(queue)} test(s)')

        if not ops.wait_ssm_online(host.instance_id):
            for test in queue:
                outcomes.append(RunOutcome(test['testId'], 'failed',
                                           f'{host.name} did not become SSM Online'))
            print(f'[cdr] {host.name}: did not become SSM Online; its tests were not run')
            return outcomes
        if not ops.wait_agent_active(host.instance_id):
            print(f'[cdr] {host.name}: WARNING: GuardDuty runtime agent not active; '
                  f'findings may be missing')

        for position, test in enumerate(queue):
            name = test['testId']
            try:
                install = build_package_install(test.get('packages'), host.os_name)
                trigger = self._read_trigger(test)
                # Best-effort install (omitted when empty), then the trigger.
                command_text = f'{install}\n{trigger}' if install else trigger
                command_id = ops.run_shell(host.instance_id, command_text)
                status = ops.wait(command_id, host.instance_id)
            except Exception as e:  # noqa: BLE001 - report and keep going
                print(f'[cdr] {name}: failed on {host.name}: {type(e).__name__}: {e}')
                outcomes.append(RunOutcome(name, 'failed', f'{type(e).__name__}: {e}'))
                status = None
            else:
                if status == 'Success':
                    print(f'[cdr] {name}: ran on {host.name}')
                    outcomes.append(RunOutcome(name, 'ran', f'command_id={command_id}'))
                else:
                    print(f'[cdr] {name}: FAILED on {host.name} (SSM status {status}, '
                          f'command {command_id})')
                    outcomes.append(RunOutcome(name, 'failed', f'SSM status {status}, command_id={command_id}'))
            if interval_seconds and position < len(queue) - 1:
                time.sleep(interval_seconds)

        # Let the sensor ship the last tests' telemetry before the run ends.
        if final_settle_seconds:
            time.sleep(final_settle_seconds)
        return outcomes
