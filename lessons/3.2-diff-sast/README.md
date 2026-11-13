# 3.2 Diff-aware SAST with a baseline

- `gate/`: security-workflows v1.1.0. Adds:
  - `rules/semgrep.yml`: four rules the gate blocks on (request data into a shell command, into
    eval/Function/vm, into a SQL string, and a deep merge of the whole request body).
  - `scripts/gate.sh`: runs Semgrep from a digest-pinned image with `--baseline-commit <merge base>`
    on pull requests, so only findings the PR adds count. On `workflow_dispatch` it scans everything.
  - The workflow checks out the repo under test with `fetch-depth: 0` and the gate's own files
    at `job.workflow_sha`, the commit the caller pinned.

```bash
ORG=<your-test-org>
cd lessons

# Compare a registry ruleset with the gate's rules on one repo (local, needs docker)
git clone -q "https://github.com/$ORG/orders-api.git" /tmp/oa
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v /tmp/oa:/src -w /src \
  semgrep/semgrep:1.185.0 semgrep scan --config p/default --metrics=off
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v /tmp/oa:/src -v "$PWD/3.2-diff-sast/gate/rules:/rules:ro" \
  -w /src semgrep/semgrep:1.185.0 semgrep scan --config /rules/semgrep.yml --metrics=off

# Release v1.1.0 and bump the fleet
ORG=$ORG 3.1-reusable-gate/publish-gate.sh 3.2-diff-sast/gate "Security gate v1.1.0: Semgrep on new findings only"
gh pr checks gate-update -R "$ORG/security-workflows" --watch
gh pr merge gate-update -R "$ORG/security-workflows" --squash --admin --delete-branch
gh api -X POST "repos/$ORG/security-workflows/git/refs" -f ref=refs/tags/v1.1.0 \
  -f sha="$(gh api "repos/$ORG/security-workflows/commits/main" --jq .sha)"
ORG=$ORG 3.1-reusable-gate/rollout-callers.sh v1.1.0 block
# merge the five PRs as in 3.1 step 3
```

Then open a PR on `orders-api` that adds `exec(\`ping -c 1 ${req.query.host}\`, ...)` (the
lesson has the full snippet). The gate fails with `shell-command-from-request` on the new line
only; the old `exec` in `/export` is not reported.
