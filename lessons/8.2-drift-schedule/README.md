# 8.2 Drift detection on a schedule

`gate/` is the 5.3 `security-workflows` content plus:

- `.github/workflows/fleet-audit.yml`: daily at 06:17 UTC and on `workflow_dispatch`. Gets a
  read-only token from a GitHub App with `actions/create-github-app-token` (SHA-pinned), runs
  `audit/fleet-audit.sh`, uploads the outputs as an artifact, and keeps one issue
  "Fleet audit: drift detected" up to date with the repo's own `GITHUB_TOKEN` (`issues: write`).
  Without the variable `FLEET_AUDIT_CLIENT_ID` and the secret `FLEET_AUDIT_PRIVATE_KEY` it
  writes a warning and checks nothing.
- `audit/fleet-audit.sh`: runs every check and writes `report.md`; exit 1 on drift.
  org (`check-org.sh` 1.1, minus `accepted-gaps.txt`), baseline (`check-drift.sh` 2.2 with the
  3.1 `baseline.json`), coverage (`check-coverage.sh`), agents (`check-agent-guardrails.sh` 7.3),
  exceptions (`exceptions-register.sh` 8.1). inventory (0.3) and bypasses (8.1) are saved, never drift.
- `audit/check-coverage.sh`: per repo: gate caller pinned to the newest `vX.Y.Z` tag in block
  mode, `dependabot.yml`, CODEOWNERS with 0 errors, the `no-pwn-triggers` event policy active,
  secret scanning + push protection.
- `audit/report-issue.sh`: opens, updates or closes the one drift issue.
- `audit/accepted-gaps.txt`: org checks you accept for now, each with an end date.
- `audit/app-manifest.json`: the read-only App (no write permission anywhere).
- the other `audit/*` files are copies of the earlier lessons' scripts and policy files.

## Run it locally

```bash
cd lessons
ORG=<your-test-org> OUT=/tmp/audit 8.2-drift-schedule/gate/audit/fleet-audit.sh; echo "exit $?"
REPO=<your-test-org>/security-workflows 8.2-drift-schedule/gate/audit/report-issue.sh /tmp/audit/report.md <0|1>
```

## Publish it

```bash
ORG=<your-test-org> 3.1-reusable-gate/publish-gate.sh 8.2-drift-schedule/gate "Add the daily fleet audit (lesson 8.2)"
gh pr checks <n> -R $ORG/security-workflows --watch --required
gh pr merge <n> -R $ORG/security-workflows --squash --admin --delete-branch
gh workflow run fleet-audit.yml -R $ORG/security-workflows
```

Don't tag this commit: the gate didn't change, and `check-coverage.sh` compares every caller with
the newest tag, so a new tag without a caller rollout shows up as drift.

## The App (needs a browser, UNTESTED in the lab)

1. Org **Settings > Developer settings > GitHub Apps > New GitHub App**, named like
   `<org>-fleet-audit`, webhook off, the permissions in `audit/app-manifest.json` (all read),
   **Only on this account**.
2. Install it on **All repositories** (the audit must see new repos too).
3. On `security-workflows`: variable `FLEET_AUDIT_CLIENT_ID` = the App's client ID, secret
   `FLEET_AUDIT_PRIVATE_KEY` = a generated private key.
4. `gh workflow run fleet-audit.yml -R $ORG/security-workflows` and read the run summary.

Whether those read permissions are enough for every check (2FA member list, outside
collaborators, installations) was not tested; a check that can't read prints `UNKNOWN` or
`FAIL ... unreadable`, which shows up as drift, not as a silent pass.

## Drift demo (what we ran)

Loosened legacy-cron's fork PR approval, deleted marketing-site's `baseline` ruleset and
orders-api's `no-pwn-triggers` policy, ran the audit (4 checks DRIFT), opened the issue, put all
three back with the lessons' own scripts, ran the audit again (clean), closed the issue.
