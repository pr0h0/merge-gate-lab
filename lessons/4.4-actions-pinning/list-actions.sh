#!/usr/bin/env bash
# List every `uses:` in the default branch workflows of every repo in the org, with
# PINNED (full SHA), LOCKED (tag recorded in .github/workflows/actions.lock) or UNPINNED. Run it before turning on SHA pinning or an allowlist:
# anything UNPINNED, or from an owner the allowlist won't cover, breaks on the next run.
#
#   ORG=<your-test-org> ./list-actions.sh
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name' | while read -r r; do
  lock=$(gh api "repos/$ORG/$r/contents/.github/workflows/actions.lock" --jq .content 2>/dev/null | base64 -d 2>/dev/null || true)
  gh api "repos/$ORG/$r/contents/.github/workflows" --jq '.[] | select(.name | test("\\.ya?ml$")) | .path' 2>/dev/null |
  while read -r f; do
    gh api "repos/$ORG/$r/contents/$f" --jq .content | base64 -d |
      { grep -oE 'uses:[[:space:]]+[^[:space:]#]+' || true; } | awk '{print $2}' | { grep -v '^\./' || true; } |
      while read -r u; do
        if [[ "$u" =~ @[0-9a-f]{40}$ ]]; then p=PINNED
        elif grep -qF -- "- '$u'" <<<"$lock"; then p=LOCKED
        else p=UNPINNED; fi
        printf '%-9s %-20s %-32s %s\n' "$p" "$r" "${f#.github/workflows/}" "$u"
      done
  done
done
