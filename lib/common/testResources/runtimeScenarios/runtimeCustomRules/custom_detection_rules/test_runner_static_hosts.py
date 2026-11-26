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
Unit tests for the static-host Custom Detection Rule runner and the distribution
of tests over hosts. They use a fake ops object (no boto3, no deployed stack, no
tester_vars) and pin:

  * prefix keys, and that tests with a common prefix land on different hosts
    (and are spread as evenly as possible when a group is larger than the host
    count);
  * the assignment is deterministic and balanced, and does not change when only
    a subset of tests is selected;
  * plan mode (ops=None) runs nothing and reports one 'built' outcome per test;
  * a real run waits for each host, then runs that host's tests one at a time;
  * a non-zero exit, or a host that never comes online, is reported as 'failed';
  * DnsTunnelingToolExecuted is out of scope on AL2023 and runs on the Ubuntu host.
'''

import collections
import os
import sys
import threading
import unittest

# This module lives inside the custom_detection_rules package; add the package's
# PARENT to sys.path so `custom_detection_rules` imports as a package.
HERE = os.path.dirname(os.path.abspath(__file__))
PARENT = os.path.dirname(HERE)
if PARENT not in sys.path:
    sys.path.insert(0, PARENT)

from custom_detection_rules.catalog import CustomDetectionRuleCatalog
from custom_detection_rules.context import build_package_install
from custom_detection_rules.distribution import assign, prefix_key
from custom_detection_rules.runner import Host, ScenarioRunner

AL_HOSTS = [Host('amazonlinux', f'CDR-AL2023-{i}', f'i-al{i}') for i in (1, 2, 3)]
UBUNTU_HOSTS = [Host('ubuntu', 'Ubuntu-GuardDutyTester', 'i-ubuntu')]


class _FakeOps:
    '''Records the calls the runner makes; can mark a host offline or a host's commands failed.'''

    def __init__(self, offline=(), failing=()):
        self.offline = set(offline)      # instance ids that never become SSM Online
        self.failing = set(failing)      # instance ids whose commands exit non-zero
        self.calls = []                  # (method, instance_id)
        self.commands = []               # (instance_id, command_text)
        self._lock = threading.Lock()
        self._counter = 0

    def _record(self, method, instance_id):
        with self._lock:
            self.calls.append((method, instance_id))

    def wait_ssm_online(self, instance_id, timeout=900):
        self._record('wait_ssm_online', instance_id)
        return instance_id not in self.offline

    def wait_agent_active(self, instance_id, timeout=600):
        self._record('wait_agent_active', instance_id)
        return True

    def run_shell(self, instance_id, command_text):
        with self._lock:
            self._counter += 1
            command_id = f'cmd-{self._counter}'
            self.commands.append((instance_id, command_text))
        self._record('run_shell', instance_id)
        return command_id

    def wait(self, command_id, instance_id, timeout=300):
        self._record('wait', instance_id)
        return 'Failed' if instance_id in self.failing else 'Success'


class DistributionTest(unittest.TestCase):

    def setUp(self):
        self.catalog = CustomDetectionRuleCatalog.load()
        self.al_ids = [t['testId'] for t in self.catalog.all_tests()
                       if self.catalog.scope_status(t['testId'], 'ec2', 'al2023')[0] == 'in']

    def test_prefix_key(self):
        self.assertEqual(prefix_key('FindCommandReconKeyMaterial'), 'FindCommand')
        self.assertEqual(prefix_key('FirewallConfigModifiedUfwDefault'), 'FirewallConfig')
        self.assertEqual(prefix_key('SSHAuthorizedKeysModification'), 'SSHAuthorized')
        self.assertEqual(prefix_key('LDPreloadFunctionHijack'), 'LDPreload')

    def test_common_prefix_tests_are_on_different_hosts(self):
        assignment = assign(self.al_ids, 3)
        groups = collections.defaultdict(list)
        for test_id in self.al_ids:
            groups[prefix_key(test_id)].append(test_id)
        checked = 0
        for key, members in groups.items():
            if len(members) < 2:
                continue
            per_host = collections.Counter(assignment[t] for t in members)
            # Spread as evenly as possible: no host holds more than ceil(n / hosts).
            self.assertLessEqual(max(per_host.values()), -(-len(members) // 3), key)
            if len(members) <= 3:
                self.assertEqual(len(per_host), len(members), f'{key} tests share a host')
            checked += 1
        self.assertGreater(checked, 0)

    def test_find_command_recon_tests_use_three_hosts(self):
        assignment = assign(self.al_ids, 3)
        recon = [t for t in self.al_ids if t.startswith('FindCommandRecon')]
        self.assertEqual(len(recon), 3)
        self.assertEqual(sorted(assignment[t] for t in recon), [0, 1, 2])

    def test_assignment_is_deterministic_and_balanced(self):
        first = assign(self.al_ids, 3)
        self.assertEqual(first, assign(list(self.al_ids), 3))
        sizes = collections.Counter(first.values())
        self.assertEqual(set(first.values()), {0, 1, 2})
        self.assertLessEqual(max(sizes.values()) - min(sizes.values()), 1)

    def test_five_hosts_separate_every_group_that_fits(self):
        assignment = assign(self.al_ids, 5)
        sizes = collections.Counter(assignment.values())
        self.assertEqual(set(assignment.values()), {0, 1, 2, 3, 4})
        self.assertLessEqual(max(sizes.values()) - min(sizes.values()), 1)
        groups = collections.defaultdict(list)
        for test_id in self.al_ids:
            groups[prefix_key(test_id)].append(test_id)
        for key, members in groups.items():
            per_host = collections.Counter(assignment[t] for t in members)
            if len(members) <= 5:
                self.assertEqual(len(per_host), len(members), f'{key} tests share a host')
            else:
                self.assertLessEqual(max(per_host.values()), 2, key)

    def test_single_host_gets_everything(self):
        self.assertEqual(set(assign(self.al_ids, 1).values()), {0})

    def test_zero_hosts_is_rejected(self):
        with self.assertRaises(ValueError):
            assign(self.al_ids, 0)


class PackageInstallTest(unittest.TestCase):

    def test_per_os_package_names(self):
        packages = {'amazonlinux': ['sqlite'], 'ubuntu': ['sqlite3']}
        al = build_package_install(packages, 'amazonlinux')
        ubuntu = build_package_install(packages, 'ubuntu')
        self.assertIn('dnf install -y sqlite ', al)
        self.assertNotIn('apt-get', al)
        self.assertIn('apt-get', ubuntu)
        self.assertIn('install -y sqlite3 ', ubuntu)

    def test_flat_list_and_empty(self):
        self.assertIn('dnf install -y curl ', build_package_install(['curl'], 'amazonlinux'))
        self.assertIn('install -y curl ', build_package_install(['curl'], 'ubuntu'))
        self.assertEqual(build_package_install([], 'ubuntu'), '')

    def test_catalog_has_no_debian_keys(self):
        catalog = CustomDetectionRuleCatalog.load()
        for test in catalog.all_tests():
            if isinstance(test['packages'], dict):
                self.assertEqual(set(test['packages']), {'amazonlinux', 'ubuntu'}, test['testId'])


class StaticHostRunnerTest(unittest.TestCase):

    def setUp(self):
        self.catalog = CustomDetectionRuleCatalog.load()
        self.runner = ScenarioRunner(self.catalog)
        # Tests in scope on AL2023 (the catalog excludes the ones that need Ubuntu).
        self.al_count = len([t for t in self.catalog.all_tests()
                             if self.catalog.scope_status(t['testId'], 'ec2', 'al2023')[0] == 'in'])

    def _run(self, selectors, os_slug='al2023', hosts=None, ops=None):
        return self.runner.run_on_hosts(
            selectors, os_slug, AL_HOSTS if hosts is None else hosts, ops=ops,
            interval_seconds=0, final_settle_seconds=0)

    def test_plan_mode_runs_nothing(self):
        outcomes = self._run(self.catalog.test_ids(), ops=None)
        built = [o for o in outcomes if o.action == 'built']
        in_scope = [t for t in self.catalog.all_tests()
                    if self.catalog.scope_status(t['testId'], 'ec2', 'al2023')[0] == 'in']
        self.assertEqual(len(built), len(in_scope))
        self.assertFalse([o for o in outcomes if o.action in ('ran', 'failed')])

    def test_each_host_is_waited_for_then_runs_its_tests(self):
        fake = _FakeOps()
        outcomes = self._run(self.catalog.test_ids(), ops=fake)
        ran = [o for o in outcomes if o.action == 'ran']
        self.assertEqual(len(ran), self.al_count)
        for host in AL_HOSTS:
            methods = [m for (m, i) in fake.calls if i == host.instance_id]
            self.assertEqual(methods[:2], ['wait_ssm_online', 'wait_agent_active'])
            body = methods[2:]
            # After the waits, each test is exactly one run_shell followed by one wait.
            self.assertEqual(body, ['run_shell', 'wait'] * (len(body) // 2))
        counts = collections.Counter(i for (i, _) in fake.commands)
        self.assertEqual(set(counts), {h.instance_id for h in AL_HOSTS})
        self.assertEqual(sum(counts.values()), self.al_count)

    def test_selecting_a_subset_keeps_each_test_on_its_host(self):
        full = _FakeOps()
        self._run(self.catalog.test_ids(), ops=full)
        subset = _FakeOps()
        self._run(['FindCommandReconKeyMaterial', 'SudoerFileLinked'], ops=subset)

        def host_of(ops, marker):
            return [i for (i, text) in ops.commands if marker in text][0]

        for marker in ('FindCommandReconKeyMaterial', 'SudoerFileLinked'):
            self.assertEqual(host_of(full, marker), host_of(subset, marker))

    def test_nonzero_exit_is_reported_as_failed(self):
        fake = _FakeOps(failing={'i-al1'})
        outcomes = self._run(self.catalog.test_ids(), ops=fake)
        failed = [o for o in outcomes if o.action == 'failed']
        self.assertTrue(failed)
        self.assertEqual(len(failed) + len([o for o in outcomes if o.action == 'ran']), self.al_count)

    def test_host_that_never_comes_online_fails_its_tests(self):
        fake = _FakeOps(offline={'i-al2'})
        outcomes = self._run(self.catalog.test_ids(), ops=fake)
        failed = [o for o in outcomes if o.action == 'failed']
        offline_tests = [t for t, h in self.runner.host_assignment('al2023', 3).items() if h == 1]
        self.assertEqual(len(failed), len(offline_tests))
        self.assertFalse([c for c in fake.commands if c[0] == 'i-al2'])

    def test_dns_tunneling_is_out_of_scope_on_al2023_and_runs_on_ubuntu(self):
        skipped = self._run(['DnsTunnelingToolExecuted'], os_slug='al2023', ops=_FakeOps())
        self.assertEqual([o.action for o in skipped], ['skipped'])

        fake = _FakeOps()
        outcomes = self._run(['DnsTunnelingToolExecuted'], os_slug='ubuntu2204',
                             hosts=UBUNTU_HOSTS, ops=fake)
        self.assertEqual([o.action for o in outcomes], ['ran'])
        self.assertEqual([i for (i, _) in fake.commands], ['i-ubuntu'])
        # Ubuntu uses apt-get, not dnf, for the package install.
        self.assertIn('apt-get', fake.commands[0][1])

    def test_ssh_from_public_ip_is_out_of_scope_on_al2023_and_runs_on_ubuntu(self):
        # The scenario logs in as the 'ubuntu' user, which Amazon Linux does not have.
        skipped = self._run(['SshFromPublicIPAddress'], os_slug='al2023', ops=_FakeOps())
        self.assertEqual([o.action for o in skipped], ['skipped'])

        fake = _FakeOps()
        outcomes = self._run(['SshFromPublicIPAddress'], os_slug='ubuntu2204',
                             hosts=UBUNTU_HOSTS, ops=fake)
        self.assertEqual([o.action for o in outcomes], ['ran'])
        self.assertEqual([i for (i, _) in fake.commands], ['i-ubuntu'])

    def test_only_the_expected_tests_need_ubuntu(self):
        ubuntu_only = sorted(t['testId'] for t in self.catalog.all_tests()
                             if self.catalog.scope_status(t['testId'], 'ec2', 'al2023')[0] == 'out')
        self.assertEqual(ubuntu_only, ['DnsTunnelingToolExecuted', 'SshFromPublicIPAddress'])

    def test_no_running_host_skips_the_tests(self):
        outcomes = self._run(['KillCommandUsage'], hosts=[], ops=_FakeOps())
        self.assertEqual([o.action for o in outcomes], ['skipped'])


if __name__ == '__main__':
    unittest.main()
