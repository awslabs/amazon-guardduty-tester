# Trigger-Prompt Library

Curated GuardDuty Investigation **trigger prompts** — the natural-language input
to `CreateInvestigation`. Copy a prompt, replace any `<FINDING_ID>` (32-char hex
finding id) / `<ACCOUNT_ID>` (12-digit account id) placeholder, and run it with
the AWS CLI (`aws guardduty create-investigation ...`).

Contributions are welcome — add a row to the table below in a PR. Keep prompts
under 2048 characters.

| No | Prompt | Notes | Contributed by |
|---|---|---|---|
| 1 | `Investigate finding <FINDING_ID> in account <ACCOUNT_ID>` | For administrators investigating a member account's finding. | guardduty |
| 2 | `Analyze findings in account with id <ACCOUNT_ID>` | Account-level sweep of recent findings. | guardduty |
| 3 | `Analyze findings in account with id <ACCOUNT_ID> and prioritize any active, high-confidence threats that need immediate response` | Useful for daily triage of a single account. | guardduty |
| 4 | `Analyze findings in my organization` | Organization-wide analysis (up to 100 accounts in preview). | guardduty |
| 5 | `Analyze findings in my organization and identify any signs of lateral movement across accounts` | Correlates signals across the organization. | guardduty |
