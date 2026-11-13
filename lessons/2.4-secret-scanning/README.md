# 2.4 Secret scanning and push protection across the org

- `secret-config.json`: a custom code security configuration that turns on secret scanning,
  push protection and non-provider patterns, and leaves every other feature `not_set` for
  later lessons. `enforcement: enforced` stops repo admins from turning the features off.
- `apply-secret-config.sh`: creates or updates the configuration by name, attaches it to every
  repo, makes it the default for new repos, and prints each repo's status. Safe to rerun.

```bash
ORG=<your-test-org>
cd lessons/2.4-secret-scanning
ORG=$ORG ./apply-secret-config.sh

# A repo admin (or the owner, at repo level) can't switch push protection off
echo '{"security_and_analysis":{"secret_scanning_push_protection":{"status":"disabled"}}}' \
  | gh api -X PATCH "repos/$ORG/legacy-cron" --input -        # 422

# Alerts (the lab's history token is a generic hex string: expect none)
for r in payments-api orders-api marketing-site internal-admin legacy-cron; do
  echo "$r $(gh api "repos/$ORG/$r/secret-scanning/alerts" --jq length)"
done
```

On GitHub Free with public repos, `secret_scanning_non_provider_patterns` is accepted in the
configuration but stays `disabled` on every repo: generic patterns need GitHub Secret
Protection on Team or Enterprise.
