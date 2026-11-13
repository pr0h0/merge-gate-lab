# 2.1 Rulesets: repo and org, free and paid

Small experiments on one repo (`legacy-cron`, the sandbox tier) to see how rulesets behave,
plus the org ruleset you would use on GitHub Team or Enterprise.

- `layer-a.json`, `layer-b.json`: two repo rulesets on the default branch, to see layering.
- `org-baseline.json`: an org ruleset for Team/Enterprise that targets repos by the `tier`
  custom property from lesson 1.3. **On Free, `POST /orgs/{org}/rulesets` returns 403.**

Everything here is deleted at the end. Lesson 2.2 applies the real baseline.

```bash
ORG=<your-test-org>
cd lessons/2.1-rulesets

# Layering: two rulesets on the same branch
A=$(gh api -X POST "repos/$ORG/legacy-cron/rulesets" --input layer-a.json --jq .id)
B=$(gh api -X POST "repos/$ORG/legacy-cron/rulesets" --input layer-b.json --jq .id)
gh api "repos/$ORG/legacy-cron/rules/branches/main" \
  --jq '.[] | "\(.type) ruleset=\(.ruleset_id) \(.parameters.required_approving_review_count // "")"'

# Evaluate mode: accepted on Free (docs say Enterprise), but nothing was recorded in our test
E=$(jq '.name="try-evaluate" | .enforcement="evaluate"' layer-a.json \
  | gh api -X POST "repos/$ORG/legacy-cron/rulesets" --input - --jq .id)

# Push rulesets: refused on public repos (422 "Source public repos cannot have push rules")
jq -n '{name: "try-push", target: "push", enforcement: "active",
  rules: [{type: "file_extension_restriction", parameters: {restricted_file_extensions: ["*.pem"]}}]}' \
  | gh api -X POST "repos/$ORG/legacy-cron/rulesets" --input -

# Org rulesets on Free
gh api -X POST "orgs/$ORG/rulesets" --input org-baseline.json      # 403 on Free

# Dry run of the org ruleset's rules as a disabled repo ruleset (GitHub validates them)
D=$(jq '.name="org-baseline-dry-run" | .enforcement="disabled" | del(.conditions.repository_property)' \
  org-baseline.json | gh api -X POST "repos/$ORG/legacy-cron/rulesets" --input - --jq .id)

# Clean up (any repo admin can do this, which is why lesson 2.2 checks for drift)
for id in $A $B $E $D; do gh api -X DELETE "repos/$ORG/legacy-cron/rulesets/$id"; done
```

On Team or Enterprise, create the org ruleset with:

```bash
gh api -X POST "orgs/$ORG/rulesets" --input org-baseline.json
```
