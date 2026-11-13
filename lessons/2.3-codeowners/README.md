# 2.3 CODEOWNERS for the files that control security

- `CODEOWNERS.template`: owner lines for `.github/`, CODEOWNERS itself, dependency manifests
  and lockfiles, `.npmrc`, Dockerfiles, IaC and `auth/` / `security/` code. `@ORG` is replaced
  with your org name.
- `rollout-codeowners.sh [repo ...]`: gives the `security` team write access to each repo
  (code owners need it) and opens one PR per repo adding `.github/CODEOWNERS`. Safe to rerun.
- `baseline.json`: the 2.2 baseline plus `require_code_owner_review: true`. Apply it with the
  2.2 scripts; it replaces the `baseline` ruleset by name.

```bash
ORG=<your-test-org>
cd lessons/2.3-codeowners

# 1. The team (works on GitHub Free; the creator becomes a maintainer)
gh api -X POST "orgs/$ORG/teams" -f name=security -f privacy=closed --jq .slug

# 2. Roll out CODEOWNERS as PRs, check each file, merge
ORG=$ORG ./rollout-codeowners.sh
gh api "repos/$ORG/payments-api/codeowners/errors?ref=add-codeowners"   # {"errors":[]}
for r in payments-api orders-api marketing-site internal-admin legacy-cron; do
  gh pr merge add-codeowners -R "$ORG/$r" --squash --delete-branch
done

# 3. Turn on code owner review in the baseline
ORG=$ORG ../2.2-baseline-ruleset/apply-baseline.sh baseline.json
ORG=$ORG ../2.2-baseline-ruleset/check-drift.sh baseline.json
```

From now on a PR that touches an owned path requests `@ORG/security` and is blocked until a
code owner approves it. In this solo lab nobody else can approve, so the org owner merges with
`gh pr merge <n> --squash --admin` (the baseline lets org admins bypass for pull requests only).
