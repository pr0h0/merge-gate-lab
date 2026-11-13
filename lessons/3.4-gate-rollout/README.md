# 3.4 Rolling out a gate: audit, warn, block, and exceptions that expire

- `gate/`: security-workflows v2.0.0.
  - `mode`: `audit` records findings in the job summary and an artifact and never fails;
    `warn` also adds warning annotations; `block` adds error annotations and fails.
  - Exceptions from `.github/security-exceptions.yml` in the repo under test: every field
    (`id`, `rule`, `path`, `reason`, `owner`, `expires`) is required, `expires` at most 90 days
    away. A valid entry covers findings with the same rule and path. An expired or invalid entry
    is a finding itself, so in block mode it fails every PR in that repo.
  - Uploads `findings.json` as the artifact `security-gate-findings` (30 days).
- `security-exceptions.example.yml`: the file format.
- `measure-noise.sh`: per repo, counts findings from the artifacts of recent runs.

```bash
ORG=<your-test-org>
cd lessons

# Release v2.0.0 (publish, wait, merge, tag as before), then roll it out in audit mode
ORG=$ORG 3.1-reusable-gate/rollout-callers.sh v2.0.0 audit
# merge the five PRs as in 3.1 step 3

# Full scan of every repo in audit mode, then count
for r in payments-api orders-api marketing-site internal-admin legacy-cron; do
  gh workflow run security.yml -R "$ORG/$r"
done
ORG=$ORG 3.4-gate-rollout/measure-noise.sh                          # latest full scan per repo
ORG=$ORG EVENT=pull_request LIMIT=20 3.4-gate-rollout/measure-noise.sh   # what PRs would have failed

# Then block
ORG=$ORG 3.1-reusable-gate/rollout-callers.sh v2.0.0 block
```
