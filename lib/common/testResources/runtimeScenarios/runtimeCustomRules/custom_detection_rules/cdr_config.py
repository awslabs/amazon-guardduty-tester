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
Folder-local static configuration for the runtime Custom Detection Rule (CDR)
harness.

The tests run on static hosts created by the CDK stack: a few Amazon Linux 2023
instances plus the existing Ubuntu instance. The harness finds them at run time
by tag/name, so no instance ids are stored here. Only the AWS region is read
from the host-generated tester_vars.py.

Keep the tag and name values below in sync with lib/stacks/constants.ts
(CDR_HOST_TAG, UBUNTU_INSTANCE_NAME).
'''

# The Amazon Linux hosts carry this tag; they are sorted by their Name tag so the
# host order (and therefore the test distribution) is stable.
CDR_HOST_TAG_KEY = 'CdrTestHost'
CDR_HOST_TAG_VALUE_AL2023 = 'al2023'

# Name tag of the existing Ubuntu instance, used for tests that cannot run on
# Amazon Linux (DnsTunnelingToolExecuted).
UBUNTU_HOST_NAME = 'Ubuntu-GuardDutyTester'

# Number of leading CamelCase words of a test id that form its prefix. Tests with
# the same prefix are spread over different hosts (see distribution.py).
PREFIX_WORDS = 2

# Seconds to wait after the GuardDuty runtime agent reports active before the
# first test on a host, so the agent's backend session is established first.
CDR_AGENT_INIT_DELAY = 30

# Seconds to wait between two tests on the same host, so each test's activity is
# separated in time and easier to match to its finding.
CDR_TEST_INTERVAL_SECONDS = 30

# Seconds to wait after the last test on a host so the Runtime Monitoring sensor
# can ship its telemetry before the run ends.
CDR_FINAL_SETTLE_SECONDS = 120
