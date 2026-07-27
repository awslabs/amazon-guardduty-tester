# GuardDuty Investigations

Prompts and an agent skill to run **Amazon GuardDuty AI-Powered Investigations
(Preview)** against your findings, accounts, and organization. GuardDuty
Investigation uses AI to analyze a finding, account, or organization and returns
a risk disposition with confidence scoring, MITRE ATT&CK® technique
classification, supporting evidence, and recommended actions.

Everything here is **independent of the CDK app** in the repo root. It works
against any account with your own AWS credentials, whether or not you deployed
the tester. Use it to:

1. **Investigate findings you generated** with the GuardDuty Tester.
2. **Investigate findings you really received** (any finding, account, or org).
3. **Investigate through an agent** using the included Kiro skill.

> AI-generated analysis and recommendations may contain errors or incomplete
> assessments. **Human review is recommended.**

## Two ways to use this

| | **Prompts** | **Skill** |
|---|---|---|
| What it is | A curated library of natural-language *trigger prompts*. The input to `CreateInvestigation` | A self-contained agent workflow that runs an investigation end to end |
| Who drives AWS | You, via the CLI or your own `aws guardduty` commands | The agent, via the [AWS API MCP Server](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/mcp-server.html) (`call_aws` / `run_script`) |
| Best for | Picking the right prompt to copy, paste, and run | Hands-off triage from a chat request |

## Prerequisites

- An active GuardDuty detector in a [supported region](#supported-regions-preview-10-total).
- The `AI_ANALYST` feature enabled on the detector. Both the CLI (`enable`
  subcommand) and the skill can enable it for you, with confirmation.
- AWS CLI ≥ **2.35.11** and a recent `boto3`/`botocore` — the preview
  Investigation APIs are missing from older SDKs and fail with
  "Invalid choice: create-investigation" / `UnknownOperation`.
- For the skill: the [AWS API MCP Server](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/mcp-server.html)
  connected to your agent (the skill calls AWS exclusively through its
  `call_aws` / `run_script` tools).
- IAM permissions: `guardduty:CreateInvestigation`, `guardduty:GetInvestigation`,
  `guardduty:ListInvestigations` (plus `GetDetector`/`UpdateDetector`/
  `ListDetectors`/`ListFindings` for setup). We recommend **ReadOnly credentials
  augmented by a scoped inline policy** granting just the three investigation
  actions on your detector ARN, rather than broad admin credentials:
  ```json
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "guardduty:CreateInvestigation",
                  "guardduty:GetInvestigation",
                  "guardduty:ListInvestigations"
              ],
              "Resource": "arn:aws:guardduty:us-west-2:123456789012:detector/<DETECTOR_ID>"
          }
      ]
  }
  ```

### Supported regions (preview, 10 total)

`us-east-1`, `us-east-2`, `us-west-2`, `ca-central-1`, `eu-central-1`,
`eu-west-1`, `eu-west-2`, `eu-west-3`, `eu-north-1`, `ap-northeast-1`

### Preview quotas

10 investigations per account per day; 100 per account total. Failed
investigations do not count. Both the CLI and the skill check and warn before
spending quota, and listing/getting past investigations is free.

## Prompts

The [`prompts/`](prompts/) directory holds a curated, browse-only
library of trigger prompts in [`library.json`](prompts/library.json). Many
entries name the tester finding type they pair with (e.g. the crypto-mining
prompt pairs with `CryptoCurrency:EC2/BitcoinTool.B!DNS`).

Browse the library from the CLI:

```bash
python3 gd_investigator.py prompts                            # list all
python3 gd_investigator.py prompts --search credential
python3 gd_investigator.py prompts --id exfil-iam-anomalous   # show one full entry
```

Copy a prompt, replace any `<FINDING_ID>` / `<ACCOUNT_ID>` placeholder, and run
it with `finding` / `account` / `org` (via the CLI, the skill, or your own
`aws guardduty` commands). For example:

```bash
python3 gd_investigator.py finding 1ab2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
```

### Contribute a prompt

Contributions are welcome. Open a PR that appends an entry to
[`library.json`](prompts/library.json)- no code changes needed. 

Use the `<FINDING_ID>` (32-char hex finding id) and `<ACCOUNT_ID>` (12-digit
account id) placeholders to keep prompts copy-paste ready. Keep prompts under
2048 characters, and make `id` unique and kebab-case. The library is validated
whenever it loads, so browsing it is a quick way to confirm your entry is valid:

```bash
python3 gd_investigator.py prompts
```

## Skills

A self-contained agent workflow that drives GuardDuty Investigation through the
AWS API MCP Server:

- **Kiro** — [`skills/kiro/guardduty-investigation/guardduty-investigation.md`](skills/kiro/guardduty-investigation/guardduty-investigation.md)

It encodes the guardrails (region allowlist, preview quotas, trigger-prompt
rules, polling, result interpretation) in prose, so an agent can run an
investigation end to end. It begins by confirming the AWS API MCP Server tools
are connected and the AWS CLI is new enough, then stops with guidance if not. It
also handles **recall**, retrieving and summarizing a *past* investigation
(latest, latest completed, or by id) without spending quota — instead of
creating a new one.

### Run the Kiro skill

1. Place the steering doc under your Kiro workspace at
   `.kiro/steering/guardduty-investigation.md` (copy the file from
   `skills/kiro/guardduty-investigation/`). It uses `inclusion: manual`, so it
   loads only when you reference it.
2. In Kiro, invoke it by context-referencing the steering file (e.g. `#`-mention
   `guardduty-investigation`) alongside your request, such as
   `Investigate GuardDuty finding <id>`.

## CLI (no agent required)

If you'd rather not use an agent, [`gd_investigator.py`](gd_investigator.py) is a
standalone CLI that runs the same investigations from a laptop or CI with boto3
and your own credentials. Install dependencies with `pip install -r
requirements.txt`, then:

```bash
python3 gd_investigator.py enable                                  # enable/verify AI_ANALYST
python3 gd_investigator.py finding 1ab2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
python3 gd_investigator.py account 123456789012                    # account-level analysis
python3 gd_investigator.py org                                     # organization-level analysis
python3 gd_investigator.py list --sort START_TIME --order DESC     # past investigations
python3 gd_investigator.py get a1b2c3d4-5678-90ab-cdef-ef1234567890 # fetch one investigation

# Learn more — no AWS calls:
python3 gd_investigator.py prompts          # browse the trigger-prompt library
```

## References

- [GuardDuty Investigation (User Guide)](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty-investigation.html)
- [CreateInvestigation](https://docs.aws.amazon.com/guardduty/latest/APIReference/API_CreateInvestigation.html)
 · [GetInvestigation](https://docs.aws.amazon.com/guardduty/latest/APIReference/API_GetInvestigation.html)
 · [ListInvestigations](https://docs.aws.amazon.com/guardduty/latest/APIReference/API_ListInvestigations.html)
- [AWS API MCP Server](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/mcp-server.html)
