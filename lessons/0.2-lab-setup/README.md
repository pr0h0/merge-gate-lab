# 0.2 Your lab: a test org and a fleet of weak repos

## Setup
1. Create a free organization in the web UI: https://github.com/organizations/plan (pick Free).
   There is no API for this on github.com.
2. Give `gh` the extra scopes the course needs:
   ```bash
   gh auth refresh -h github.com -s admin:org,delete_repo
   gh auth status          # Token scopes should include admin:org and delete_repo
   ```
3. Clone this repo and build the fleet:
   ```bash
   ORG=<your-test-org>
   git clone https://github.com/pr0h0/merge-gate-lab.git && cd merge-gate-lab
   ./bootstrap/bootstrap.sh "$ORG" --local   # optional: build ./fleet/ only, no GitHub calls
   ./bootstrap/bootstrap.sh "$ORG"           # create and push the 5 public repos
   ```
   Safe to rerun: it reuses `./fleet/`, creates a missing repo, and pushes only to a repo with no `main` yet.

## Check
```bash
gh repo list "$ORG" --json name,visibility --jq '.[] | "\(.name) \(.visibility)"'
for r in payments-api orders-api marketing-site internal-admin legacy-cron; do
  gh run list -R "$ORG/$r" -L 1 --json workflowName,event,conclusion \
    --jq ".[] | \"$r \(.workflowName) \(.event) \(.conclusion)\""
done
git -C fleet/payments-api log --oneline   # 3 commits; the middle one adds .env
```

## Teardown (when the course is over)
```bash
for r in payments-api orders-api marketing-site internal-admin legacy-cron; do
  gh repo delete "$ORG/$r" --yes
done
rm -rf fleet/
```
Then delete the org in the web UI: org Settings, General, "Delete this organization" at the bottom.
