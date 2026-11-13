# 8.1 Exceptions and bypasses you can audit

Files:

- `exceptions-register.sh`: reads `.github/security-exceptions.yml` (the 3.4 format) from every
  repo and prints one register: status (`OK`, `SOON` = within `WARN_DAYS`, default 14, `EXPIRED`,
  `INVALID` = missing field, bad date or more than 90 days away), owner, expiry, days left and the
  commit that last changed the file. Writes `register.json`. Exit 1 on EXPIRED or INVALID.
  Needs `gh`, `jq` and yq v4 (`YQ="docker run --rm -i mikefarah/yq:4.54.1"` if you don't have it).
- `bypasses.sh`: every ruleset bypass from the rule insights API
  (`GET /repos/{o}/{r}/rulesets/rule-suites?rule_suite_result=bypass`), with the actor, the PR,
  the rules that were skipped and whether the PR has a `Bypass: <reason>` comment. Writes
  `bypasses.json`. Exit 1 if any bypass has no reason. `PERIOD=hour|day|week|month` (the API
  keeps one month).
- `bypass-policy.md`: a policy template: who may bypass, when, how it is recorded, how the
  weekly review runs.

## Run it

```bash
cd lessons
ORG=<your-test-org> 8.1-exceptions-bypasses/exceptions-register.sh; echo "exit $?"
ORG=<your-test-org> TODAY=2026-12-31 8.1-exceptions-bypasses/exceptions-register.sh   # a future date
ORG=<your-test-org> PERIOD=week 8.1-exceptions-bypasses/bypasses.sh | tail -8
```

Record a reason before a bypass:

```bash
gh pr comment <n> -R $ORG/<repo> --body "Bypass: <why>, <ticket>"
gh pr merge <n> -R $ORG/<repo> --squash --admin --delete-branch
```

The audit log (who changed a ruleset, who bypassed branch protection) is in the org's web UI on
Free and Team (180 days, owners only); its API needs Enterprise Cloud. The rule insights API is
the part you can script on Free.
