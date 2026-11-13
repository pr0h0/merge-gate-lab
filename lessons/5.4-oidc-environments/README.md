# 5.4 OIDC, environments and runners

- `oidc-claims.yml`: `workflow_dispatch` demo. Job `no-environment` and job `prod` (environment
  `prod`) each request an OIDC token with audience `merge-gate-lab-demo` and print the decoded
  claims. The raw token is masked and never printed.
- `setup-environment.sh <repo> [true|false]`: environment `prod` with the `security` team as
  required reviewer, `main` as the only deployment branch, admin bypass off, and a fake
  environment secret `DEPLOY_NOTE`. The second argument is `prevent_self_review`.
- `deploy-aws.example.yml` + `trust-policy.example.json`: the AWS pattern (not run: no cloud
  account). Replace `ORG_ID` and `REPO_ID` with the values from the `sub` your repo really gets.

```bash
ORG=<your-test-org>
cd lessons

5.4-oidc-environments/setup-environment.sh legacy-cron false
ORG=$ORG 4.1-dependabot/fleet-pr.sh oidc-claims "Add the OIDC claims demo" "cp $PWD/5.4-oidc-environments/oidc-claims.yml .github/workflows/" legacy-cron
ORG=$ORG 4.1-dependabot/merge-fleet-prs.sh oidc-claims legacy-cron

# On main: prod waits for a reviewer
gh workflow run oidc-claims.yml -R "$ORG/legacy-cron"
id=$(gh run list -R "$ORG/legacy-cron" -w oidc-claims -L 1 --json databaseId --jq '.[0].databaseId')
gh api "repos/$ORG/legacy-cron/actions/runs/$id/pending_deployments" --jq '.[] | {env: .environment.name, current_user_can_approve}'
eid=$(gh api "repos/$ORG/legacy-cron/environments/prod" --jq .id)
gh api -X POST "repos/$ORG/legacy-cron/actions/runs/$id/pending_deployments" -F "environment_ids[]=$eid" -f state=approved -f comment=ok
gh run view "$id" -R "$ORG/legacy-cron" --log | grep -E '"(sub|aud|environment|ref)"'

# From another branch: prod is refused by the branch policy
git push origin main:refs/heads/oidc-branch   # in a clone
gh workflow run oidc-claims.yml -R "$ORG/legacy-cron" --ref oidc-branch

# Self-hosted runners: none on any repo
gh api -X PUT "orgs/$ORG/actions/permissions/self-hosted-runners" -f enabled_repositories=none
gh api "orgs/$ORG/actions/runner-groups" --jq '.runner_groups[] | {name, allows_public_repositories}'

# OIDC sub template (org template applies only to repos that opt in with use_default=false)
gh api "orgs/$ORG/actions/oidc/customization/sub"
gh api "repos/$ORG/legacy-cron/actions/oidc/customization/sub"
```
