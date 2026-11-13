# 2.2 A baseline ruleset on every repo, put back when it drifts

On GitHub Free there are no org rulesets, so the baseline is a **repo** ruleset copied to
every repo by a script, and a second script checks that every copy still matches.

- `baseline.json`: the ruleset, named `baseline`, on the default branch. Blocks deletion and
  force pushes, requires linear history, requires a pull request (0 approvals, so one person
  can run the lab), conversation resolution, squash merges only. Org admins can bypass it
  **for pull requests only**: they can merge a PR that doesn't meet the rules, but they can't
  push to `main` directly.
- `apply-baseline.sh [file] [repo ...]`: creates or overwrites the ruleset by name on every
  non-archived repo. Safe to rerun.
- `check-drift.sh [file]`: prints `OK`, `MISSING` or `CHANGED` per repo, exits 1 on any drift.
  `FIX=1` puts the file's version back.

Both scripts take any ruleset file, so later lessons extend the baseline by shipping their own
copy with more rules (2.3 adds code owner review, module 3 adds required checks) and applying
it with the same name. The newest file is the one to check against.

```bash
ORG=<your-test-org>
cd lessons/2.2-baseline-ruleset
ORG=$ORG ./check-drift.sh          # MISSING x5 on a fresh fleet
ORG=$ORG ./apply-baseline.sh
ORG=$ORG ./check-drift.sh          # OK x5

# Drift, as a repo admin could do it
id=$(gh api "repos/$ORG/orders-api/rulesets" --jq '.[] | select(.name=="baseline") | .id')
gh api -X PUT "repos/$ORG/orders-api/rulesets/$id" -f enforcement=disabled --silent
id=$(gh api "repos/$ORG/marketing-site/rulesets" --jq '.[] | select(.name=="baseline") | .id')
gh api -X DELETE "repos/$ORG/marketing-site/rulesets/$id"
ORG=$ORG ./check-drift.sh          # CHANGED orders-api, MISSING marketing-site, exit 1
ORG=$ORG FIX=1 ./check-drift.sh    # puts both back
ORG=$ORG ./check-drift.sh          # OK x5
```

Direct push to `main` (rejected, even for an org owner):

```bash
git clone "https://github.com/$ORG/payments-api.git" && cd payments-api
echo "# test" >> README.md && git commit -am "Direct push to main" && git push origin main
# remote: error: GH013: Repository rule violations found for refs/heads/main.
# remote: - Changes must be made through a pull request.
```

In a real org, set `required_approving_review_count` to 1 or 2, keep
`dismiss_stale_reviews_on_push`, add `require_last_push_approval`, and empty the bypass list
or limit it to a break-glass team.
