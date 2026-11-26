# Runtime Custom Detection Rule (CDR) Test Harness

A self-contained harness for validating GuardDuty **Runtime Monitoring Custom
Detection Rules** with benign triggers. The tests run on **static EC2 hosts that
the CDK stack creates**: five Amazon Linux 2023 instances
(`CDR-AL2023-GuardDutyTester-1` to `-5`, `t3.small`) and the existing
Ubuntu instance (`Ubuntu-GuardDutyTester`). The harness does not create or
terminate any instance.

## Prerequisites

- The GuardDuty tester stack is deployed and you are connected to the **driver**
  instance over SSM (see the repository root `README.md`).
- **Each custom detection rule you intend to test is associated and LIVE in
  GuardDuty before you run.** The harness only produces the benign activity that
  triggers a rule; it does not create or enable rules.
- [Runtime Monitoring](https://docs.aws.amazon.com/guardduty/latest/ug/runtime-monitoring-configuration.html)
  and automated agent management for EC2 are enabled in the account.
- The test hosts are running and registered with SSM. They install the GuardDuty
  agent themselves at boot, so give a freshly deployed stack a few minutes.

## Usage

Run everything from this folder on the driver host:

```bash
cd /home/ssm-user/py_tester/runtimeScenarios/runtimeCustomRules

# Run every test in the catalog
python3 ./run_test.py --all

# Run all tests of one rule (a ruleId expands to every test of that rule)
python3 ./run_test.py --custom-rule FirewallConfigModified

# Run one specific test (a testId runs just that test)
python3 ./run_test.py --custom-rule FirewallConfigModifiedUfwDefault

# Run several, mixing rule ids and test ids
python3 ./run_test.py --custom-rule FirewallConfigModified KillCommandUsage

# Force the whole run onto one OS (optional; see "Target OS" below)
python3 ./run_test.py --custom-rule FirewallConfigModified --os ubuntu2204
```

`--custom-rule` and `--all` are mutually exclusive; exactly one is required. The
exit code is 0 only if at least one test ran and none failed.

## How tests are spread over the hosts

Tests that share a name prefix are placed on **different** hosts. The prefix is
the first two CamelCase words of the test id (for example `FindCommand` for
`FindCommandReconKeyMaterial`, `FirewallConfig` for
`FirewallConfigModifiedUfwDefault`).

- A prefix group with no more tests than there are hosts (for example the three
  `FindCommandRecon*` tests) gets one test per Amazon Linux host.
- A larger group cannot be fully separated, so it is spread as evenly as
  possible. With five hosts only `SudoerFile*` (6 tests) is larger than the host
  count, so two of its tests share a host.
- The 68 Amazon Linux tests split 14 / 14 / 14 / 13 / 13.
- The assignment is computed from the whole catalog, so a test always runs on the
  same host, however many tests you select.

Hosts run **in parallel**. The tests on one host run **one after another**, with
a pause between them (`CDR_TEST_INTERVAL_SECONDS`) so each test's activity is
separated in time, and a final wait (`CDR_FINAL_SETTLE_SECONDS`) so the Runtime
Monitoring sensor can ship the last telemetry.

## Target OS

By default each selected test runs on the OS it is in scope for: **Amazon Linux
2023** for almost every test, and the **Ubuntu** host for two tests that cannot run
on Amazon Linux:

- `DnsTunnelingToolExecuted`: its `iodine`/`dns2tcp` tools are not in the AL2023
  repositories.
- `SshFromPublicIPAddress`: it logs in as the `ubuntu` user, which Amazon Linux
  does not have.

Both are recorded as AL2023 exclusions in the catalog `scope` section, so a single
`--all` run covers every test on the right host.

Pass `--os {al2023,ubuntu2204}` to force the whole run onto one OS instead; tests
out of scope for that OS are reported as skipped.

## What happens on each host

1. Wait for the host to be SSM Online and the GuardDuty runtime agent to be active.
2. For each assigned test: install its packages (best effort) and run its benign
   trigger once, in one SSM `AWS-RunShellScript` command, then check the result.
3. A trigger that exits non-zero is reported as `FAILED` with the SSM command id;
   a host that never comes online fails all of its tests.

Because the hosts are reused, the test scripts are written to be re-runnable
(for example they remove an account or link left by a previous run before
creating it). A few tests leave small, benign changes behind (for example the
`benign_tmpuser` account, or ASLR turned off until the next reboot).

After a run, check the GuardDuty console in the account/region for the expected
finding type (recorded per rule in `custom_detection_rules.json`).

## Layout

| Path | Purpose |
|---|---|
| `run_test.py` | Single entry point (`--custom-rule` / `--all` / `--os`). |
| `README.md` | This file. |
| `custom_detection_rules/` | The harness package. |
| `custom_detection_rules/catalog.py` | Catalog loader. |
| `custom_detection_rules/distribution.py` | Prefix grouping and assignment of tests to hosts. |
| `custom_detection_rules/runner.py` | AWS-free runner: runs each host's tests in order. |
| `custom_detection_rules/context.py` | Shared helpers (package install, run id). |
| `custom_detection_rules/cdr_config.py` | Static settings (host tag/name, prefix length, timings). |
| `custom_detection_rules/static_host_ops.py` | boto3 EC2/SSM operations: find hosts, wait, run. |
| `custom_detection_rules/custom_detection_rules.json` | The catalog: rules, tests, per-OS packages, and compute/OS scope. |
| `custom_detection_rules/scenarios/*.sh` | One benign trigger script per test. |
| `custom_detection_rules/test_runner_static_hosts.py` | Unit tests (no AWS or deployed stack needed). |

## Configuration

Static settings live in `custom_detection_rules/cdr_config.py`. The host names
and tag must match `lib/stacks/constants.ts` (`CDR_HOST_TAG`,
`UBUNTU_INSTANCE_NAME`). The number of Amazon Linux hosts is `CDR_HOST_COUNT` in
`constants.ts`; the harness discovers however many are running. Only the AWS
region is read from the host-generated `tester_vars.py`.
