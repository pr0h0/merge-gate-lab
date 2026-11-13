# 5.3 zizmor across the fleet

- `gate/`: security gate v2.3.0 (copy of 4.3's v2.2.0 plus zizmor). `scripts/gate.sh` step 4b runs
  `ghcr.io/zizmorcore/zizmor:1.32.0` (pinned by digest) on the PR's head and on the merge base,
  online audits on (`GH_TOKEN`). New High findings (matched on file, audit and the code they point
  at) fail the gate; every finding goes to `zizmor.sarif`, which `security-gate.yml` uploads to code
  scanning (`github/codeql-action/upload-sarif`, category `zizmor`).
- `caller.yml.template`: the caller now grants `security-events: write` to the `security` job. A
  called workflow can't get more than its caller gives it, so v2.3.0 must be rolled out with this
  template (`TEMPLATE=...`), not by a Dependabot SHA bump.

```bash
ORG=<your-test-org>
cd lessons

# Before: counts per repo (same scan as lesson 1.2)
(cd 1.2-fleet-scan && ORG=$ORG ./fleet-scan.sh)

# Publish, merge, tag, roll out
ORG=$ORG 3.1-reusable-gate/publish-gate.sh 5.3-zizmor-fleet/gate "Security gate v2.3.0: zizmor"
gh pr checks gate-update -R "$ORG/security-workflows" --watch
gh pr merge gate-update -R "$ORG/security-workflows" --squash --admin --delete-branch
sha=$(gh api "repos/$ORG/security-workflows/commits/main" --jq .sha)
gh api -X POST "repos/$ORG/security-workflows/git/refs" -f ref=refs/tags/v2.3.0 -f sha="$sha"
TEMPLATE=$PWD/5.3-zizmor-fleet/caller.yml.template ORG=$ORG 3.1-reusable-gate/rollout-callers.sh v2.3.0 block
ORG=$ORG 4.1-dependabot/merge-fleet-prs.sh security-gate

# Report everything: full scans upload SARIF for main
for r in payments-api orders-api marketing-site internal-admin legacy-cron; do gh workflow run security.yml -R "$ORG/$r"; done
gh api "repos/$ORG/orders-api/code-scanning/analyses" --jq '.[] | {ref, category, results_count}'

# After
(cd 1.2-fleet-scan && ORG=$ORG ./fleet-scan.sh)
```

Note: zizmor reads `.github/workflows/actions.lock` only when the input is a git checkout. The
gate's checkout is one, so payments-api's tag-plus-lockfile pins pass there; the fleet scan from
1.2 unpacks files without `.git` and still reports them as `unpinned-uses`.
