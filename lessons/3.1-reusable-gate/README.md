# 3.1 One reusable security workflow for the whole fleet

- `gate/`: the first version (v1.0.0) of the org's central repo `security-workflows`:
  - `.github/workflows/security-gate.yml`: the reusable workflow (`on: workflow_call`, input `mode`).
    Job `gate` only checks its input and writes a summary in this version.
  - `.github/workflows/self-test.yml`: runs the PR's own version of the gate on every PR to
    `security-workflows`, with the same check name as the fleet (`security / gate`).
  - `.github/CODEOWNERS`: the whole repo is owned by `@ORG/security`.
  - `.github/actionlint.yaml`: actionlint 1.7.12 doesn't know `job.workflow_sha` yet; ignore that one error.
- `publish-gate.sh <gate-dir> "<message>"`: first run creates the public repo and pushes `main`;
  later runs open a PR from branch `gate-update`.
- `caller.yml.template`: the caller every repo gets as `.github/workflows/security.yml`.
- `rollout-callers.sh <tag> [audit|warn|block] [repo ...]`: one PR per repo that adds or bumps the
  caller, pinned to the full SHA behind the tag. Skips `security-workflows`. Safe to rerun.
- `baseline.json`: the 2.3 baseline plus a required status check `security / gate` from the
  GitHub Actions app (`integration_id` 15368).

The scripts need gh with the `workflow` scope (`gh auth refresh -s workflow`), because they write
workflow files.

```bash
ORG=<your-test-org>
cd lessons/3.1-reusable-gate

# 1. The central repo, and a tag to pin
ORG=$ORG ./publish-gate.sh gate "Security gate v1.0.0: reusable workflow skeleton"
gh api -X POST "repos/$ORG/security-workflows/git/refs" -f ref=refs/tags/v1.0.0 \
  -f sha="$(gh api "repos/$ORG/security-workflows/commits/main" --jq .sha)"

# 2. Callers, one PR per repo; read the real check name from a run
ORG=$ORG ./rollout-callers.sh v1.0.0 block
gh pr checks security-gate -R "$ORG/payments-api" --watch

# 3. Merge them once the gate passed (code-owned path: --admin in a solo lab)
for r in payments-api orders-api marketing-site internal-admin legacy-cron; do
  gh pr checks security-gate -R "$ORG/$r" --watch --required >/dev/null &&
    gh pr merge security-gate -R "$ORG/$r" --squash --admin --delete-branch
done

# 4. Make the check required everywhere (security-workflows too: its self-test gives the same name)
ORG=$ORG ../2.2-baseline-ruleset/apply-baseline.sh baseline.json
ORG=$ORG ../2.2-baseline-ruleset/check-drift.sh baseline.json
```

To release a new gate version: `publish-gate.sh <dir>`, wait for the self-test, merge, tag the
merge commit `vX.Y.Z`, then `rollout-callers.sh vX.Y.Z <mode>` and merge the PRs.
