# 4.1 Dependabot across the fleet

- `dependabot.yml.template`: version updates for every fleet repo (`@ORG@` is replaced).
  npm and github-actions, weekly on Monday 06:00 UTC, at most 5 open PRs per ecosystem,
  `cooldown` 7 days (30 for majors), one grouped PR for minor/patch npm bumps, one for npm
  security fixes, one for third-party actions. The org's own gate (`security-workflows`) is
  excluded from cooldown and from the actions group, so its bump always comes as its own PR.
- `fleet-pr.sh <branch> "<title>" '<command>' [repo ...]`: runs a command in a fresh clone of
  every fleet repo and opens one PR per repo with the result. Lessons 4.2 and 4.4 reuse it.
- `merge-fleet-prs.sh <branch> [repo ...]`: waits for `security / gate` on each repo's PR from
  that branch and squash-merges it (`--admin`: a one-person lab can't get a code owner review).
- `gate/`: security-workflows v2.0.1 = v2.0.0 plus `.github/dependabot.yml`, so the gate's own
  actions stay current. Releasing it gives Dependabot a newer tag to propose to the callers.

```bash
ORG=<your-test-org>
cd lessons

# 1. Alerts and security updates on every repo, through the enforced configuration from 2.4
id=$(gh api "orgs/$ORG/code-security/configurations" --jq '.[] | select(.name=="secret-protection") | .id')
gh api -X PATCH "orgs/$ORG/code-security/configurations/$id" \
  -f dependabot_alerts=enabled -f dependabot_security_updates=enabled \
  --jq '{dependabot_alerts, dependabot_security_updates}'
gh api "repos/$ORG/payments-api/dependabot/alerts" \
  --jq '.[] | "\(.security_advisory.ghsa_id) \(.security_advisory.severity) \(.dependency.package.name) fix \(.security_vulnerability.first_patched_version.identifier)"'

# 2. Release gate v2.0.1 (publish, wait for the self-test, merge, tag), as in 3.1
ORG=$ORG 3.1-reusable-gate/publish-gate.sh 4.1-dependabot/gate "Security gate v2.0.1: Dependabot keeps the gate's own actions up to date"

# 3. dependabot.yml to every repo, one PR each, then merge
ORG=$ORG 4.1-dependabot/fleet-pr.sh dependabot-config "Add Dependabot version updates (npm and GitHub Actions)" \
  "mkdir -p .github && sed \"s|@ORG@|\$ORG|g\" $PWD/4.1-dependabot/dependabot.yml.template > .github/dependabot.yml"
ORG=$ORG 4.1-dependabot/merge-fleet-prs.sh dependabot-config

# 4. A few minutes later: what Dependabot opened
for r in payments-api orders-api marketing-site internal-admin legacy-cron; do
  gh pr list -R "$ORG/$r" --author app/dependabot --json number,title --jq ".[] | \"$r #\(.number) \(.title)\""
done
```

Merge the gate bump and the security fix with `merge-fleet-prs.sh <branch>`, using the PR's
branch name (`gh pr list --json headRefName`). For a major you don't want, comment
`@dependabot ignore this major version` on the PR.
