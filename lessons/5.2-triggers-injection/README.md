# 5.2 Dangerous triggers and script injection

- `fix-triggers.sh`: run in a repo checkout. `ci.yml`: `pull_request_target` -> `pull_request`,
  drops the head checkout and the fork guard, passes the PR title through `env`. `triage.yml`:
  passes the comment body through `env`; keeps `issue_comment` with a `zizmor: ignore` comment
  that states why. Safe to rerun.
- `event-policy.json` + `apply-event-policy.sh`: a repo-level Actions event policy on every repo
  that allows every event except `pull_request_target` and `workflow_run`. Org-level policies need
  Team; repo-level ones work on Free public repos (repo admins can delete them).

```bash
ORG=<your-test-org>
cd lessons

# 1. The injection, before the fix (as an org owner or member; the payload is harmless)
n=$(gh issue create -R "$ORG/legacy-cron" --title "Triage demo" --body "demo" | grep -oE '[0-9]+$')
gh issue comment "$n" -R "$ORG/legacy-cron" --body '"; echo INJECTED-$((6*7)) #'
id=$(gh run list -R "$ORG/legacy-cron" -w triage -L 1 --json databaseId --jq '.[0].databaseId')
gh run view "$id" -R "$ORG/legacy-cron" --log | grep -A6 'Run echo'      # INJECTED-42

# 2. Fix the fleet
ORG=$ORG 4.1-dependabot/fleet-pr.sh fix-triggers "ci on pull_request; untrusted text through env" "$PWD/5.2-triggers-injection/fix-triggers.sh"
ORG=$ORG 4.1-dependabot/merge-fleet-prs.sh fix-triggers

# 3. Same comment again: printed as text
gh issue comment "$n" -R "$ORG/legacy-cron" --body '"; echo INJECTED-$((6*7)) #'

# 4. Block pull_request_target and workflow_run on every repo
ORG=$ORG 5.2-triggers-injection/apply-event-policy.sh
gh issue close "$n" -R "$ORG/legacy-cron"
```
