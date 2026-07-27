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
Shared constants for GuardDuty Investigation tooling.
All values reflect the GuardDuty Investigation (Preview) feature as of June 2026.
'''

# Name of the detector feature that must be enabled for investigations.
AI_ANALYST_FEATURE = 'AI_ANALYST'

# The 10 commercial regions where GuardDuty Investigation is available in preview.
SUPPORTED_REGIONS = {
    'us-east-1',
    'us-east-2',
    'us-west-2',
    'ca-central-1',
    'eu-central-1',
    'eu-west-1',
    'eu-west-2',
    'eu-west-3',
    'eu-north-1',
    'ap-northeast-1',
}

# Preview quotas (per account). Failed investigations do not count toward these.
MAX_INVESTIGATIONS_PER_DAY = 10
MAX_INVESTIGATIONS_TOTAL = 100

# triggerPrompt length constraint from the CreateInvestigation API.
MAX_TRIGGER_PROMPT_LEN = 2048

# Investigation lifecycle statuses returned by GetInvestigation.
STATUS_COMPLETED = 'COMPLETED'
STATUS_FAILED = 'FAILED'
TERMINAL_STATUSES = {STATUS_COMPLETED, STATUS_FAILED}

# Valid sort attributes / order for ListInvestigations.
SORT_ATTRIBUTES = {'START_TIME', 'END_TIME', 'STATUS', 'RISK_LEVEL', 'CONFIDENCE'}
SORT_ORDERS = {'ASC', 'DESC'}

# A GuardDuty finding ID is a 32-character hexadecimal string.
FINDING_ID_PATTERN = r'^[a-f0-9]{32}$'

# An AWS account ID is a 12-digit number.
ACCOUNT_ID_PATTERN = r'^[0-9]{12}$'

# Default polling behaviour when waiting for an investigation to finish.
DEFAULT_POLL_TIMEOUT_SECONDS = 600
DEFAULT_POLL_INTERVAL_SECONDS = 60

# Human-review caveat appended to every rendered report.
HUMAN_REVIEW_CAVEAT = (
    'AI-generated analysis and recommendations may contain errors or incomplete '
    'assessments. Human review is recommended.'
)
