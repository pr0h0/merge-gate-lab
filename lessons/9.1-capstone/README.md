# 9.1 Capstone: harden the fleet and prove it

`collect-evidence.sh` reruns the course's scripts and writes `evidence/`:

| File | What | From |
|---|---|---|
| `summary.md` | the checklist below with yes/no, plus the key tables | all |
| `audit/` | org, baseline drift, coverage, agent guardrails, exceptions, inventory (after), bypasses | 8.2 `fleet-audit.sh` |
| `inventory-before.json`, `inventory-diff.md` | every org and repo setting that changed | 0.3 |
| `scan/`, `scan-before.json`, `zizmor.md` | zizmor (and gitleaks, Semgrep) before and after | 1.2 `fleet-scan.sh` |
| `blocked-prs.md` | closed PRs whose last `security / gate` run failed, with the gate's messages | 3.x-7.x demo PRs |
| `baseline.json` | the baseline ruleset the drift check compares with | 3.1 |
| `managed-settings.json`, `managed-settings-note.md` | your Claude Code policy and your note | 6.1 |

```bash
cd lessons
ORG=<your-test-org> \
BEFORE=0.3-inventory/before.json \
BEFORE_SCAN=<the summary.json you saved in 1.2> \
MANAGED=6.1-managed-settings/managed-settings.json \
NOTE=<your note>.md \
  9.1-capstone/collect-evidence.sh; echo "exit $?"
```

It takes about five minutes (the audit's bypass lookup and the fleet scan). `SKIP_SCAN=1` reuses
`evidence/scan/`. Exit 1 lists what is missing. It only reads; nothing in the org changes.

`evidence/` contains scan reports (redacted, still sensitive) and your org's settings. Don't
publish it as is; submit `summary.md` and the files the checklist names.

## Grading checklist (the final project)

| # | Requirement | Evidence | Pass when |
|---|---|---|---|
| 1 | Inventory before and after | `inventory-before.json`, `audit/inventory.json`, `inventory-diff.md` | before is from module 0, after is from today; secret scanning, push protection, rulesets and Dependabot changed on every repo |
| 2 | Baseline ruleset, zero drift | `baseline.json`, `audit/baseline.txt` | `OK` for every repo, no `MISSING`/`CHANGED` |
| 3 | A PR the central gate blocked, with the reason | `blocked-prs.md` | a link, the failing check and its message |
| 4 | A dependency PR rejected by the package check | `blocked-prs.md` (`packages ...` or `lockfile ...`) | an invented, too-new or non-registry package was refused |
| 5 | zizmor before and after | `zizmor.md` | high findings went down; any left are explained |
| 6 | managed-settings.json with a note | `managed-settings.json`, `managed-settings-note.md` | valid JSON; the note says what it enforces and at least two things it can't |
| 7 | Exceptions log with at least one expiring exception | `audit/exceptions.txt` | at least one entry with an owner and an expiry within 90 days |

## Rubric (100 points)

- Evidence complete and real (items 1-7 present, from the learner's own org, dates make sense): 40
- Zero drift and a clean fleet audit, or every remaining finding accepted with an owner and a date: 15
- The blocked PRs show different checks (code, secret, dependency, workflow), not one kind: 10
- The managed-settings note is honest about limits (Read deny vs shell, unmanaged machines, other agents): 10
- The exception and bypass record: reasons written, nothing expired, bypasses reviewed: 10
- A one-page write-up: what is still weak, who can still switch each control off, what they would do next on Team or Enterprise: 15
