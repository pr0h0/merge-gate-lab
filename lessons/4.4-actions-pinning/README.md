# 4.4 Actions are dependencies too: pinning, allowlists and lockfiles

- `list-actions.sh`: every `uses:` in every repo's workflows on the default branch, marked
  PINNED (full SHA), LOCKED (in `.github/workflows/actions.lock`) or UNPINNED.
- `pin-actions.sh`: in a checkout, rewrites `uses: owner/repo@<tag>` to
  `@<full SHA> # <most specific tag on that commit>` (v7 becomes `# v7.0.1`). Run it through
  `fleet-pr.sh` for every repo.
- `actions-policy.json` + `apply-actions-policy.sh`: org Actions policy. SHA pinning required;
  allowed: GitHub-owned, verified Marketplace creators, the org's own repos (always allowed
  with `selected`) and `zizmorcore/zizmor-action@*`.

Order matters: pin, check, then enforce.

```bash
ORG=<your-test-org>
cd lessons

ORG=$ORG 4.4-actions-pinning/list-actions.sh                     # UNPINNED lines = what will break
ORG=$ORG 4.1-dependabot/fleet-pr.sh pin-actions "Pin every action to a full commit SHA" "$PWD/4.4-actions-pinning/pin-actions.sh"
ORG=$ORG 4.1-dependabot/merge-fleet-prs.sh pin-actions
ORG=$ORG 4.4-actions-pinning/list-actions.sh | grep -c UNPINNED  # expect 0
ORG=$ORG 4.4-actions-pinning/apply-actions-policy.sh

# Workflow dependency lockfile (a gh extension, not built into gh)
gh extension install github/gh-actions-lock --pin v0.4.1
gh repo clone "$ORG/payments-api" /tmp/payments-api && cd /tmp/payments-api && gh actions-lock && git diff
```
