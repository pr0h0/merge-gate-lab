# 5.1 The GITHUB_TOKEN and least privilege

- `token-demo.yml` + `token-probe.sh`: a demo workflow for a PR (never merge it). Job
  `write-token` asks for `contents: write` and `pull-requests: write`, job `read-token` for
  `contents: read`; both try the same seven things (comment, approve, create a branch, create a
  release, add a workflow file by API, push a workflow file with git, move `main`) and print
  ALLOWED or DENIED. Job `where-checkout-keeps-the-token` shows where `actions/checkout` puts the
  token when `persist-credentials` is left at its default.
- `least-privilege.sh`: run in a repo checkout. Adds `permissions: {}` at the top of `ci.yml` and
  `triage.yml`, `contents: read` to the ci job, and `persist-credentials: false` to every checkout.
  Safe to rerun.

```bash
ORG=<your-test-org>
cd lessons

# What a token had before: the header of a recent ci run log
id=$(gh run list -R "$ORG/legacy-cron" -w ci -L 1 --json databaseId --jq '.[0].databaseId')
gh run view "$id" -R "$ORG/legacy-cron" --log | grep -A5 'GITHUB_TOKEN Permissions'

# The demo PR (in a clone of legacy-cron)
git checkout -b token-demo
cp <lab>/lessons/5.1-token-permissions/token-demo.yml .github/workflows/
cp <lab>/lessons/5.1-token-permissions/token-probe.sh .github/
git add -A && git commit -m "token-demo" && git push -u origin token-demo
gh pr create --title "token-demo (do not merge)" --body "Lesson 5.1"
gh run view <run-id> --log | grep -E 'ALLOWED|DENIED|GITHUB_TOKEN Permissions' -A0

# Clean up what the write token created, then close the PR
for t in $(gh release list --json tagName --jq '.[].tagName' | grep token-demo); do gh release delete "$t" --cleanup-tag -y; done
for b in $(gh api "repos/$ORG/legacy-cron/branches" --jq '.[].name' | grep '^token-demo-'); do gh api -X DELETE "repos/$ORG/legacy-cron/git/refs/heads/$b"; done
gh pr close token-demo --delete-branch

# Fix the fleet
ORG=$ORG 4.1-dependabot/fleet-pr.sh least-privilege "Least-privilege GITHUB_TOKEN" "$PWD/5.1-token-permissions/least-privilege.sh"
ORG=$ORG 4.1-dependabot/merge-fleet-prs.sh least-privilege
```
