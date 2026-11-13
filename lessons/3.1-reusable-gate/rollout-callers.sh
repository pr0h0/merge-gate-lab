#!/usr/bin/env bash
# Open one PR per repo that adds or updates .github/workflows/security.yml, the small caller of
# the central gate, pinned to the full commit SHA behind a tag of $ORG/security-workflows.
# The same script rolls out a new version or a new mode. Safe to rerun: repos already on the
# same file, or with an open rollout PR, are skipped. Needs gh (`workflow` scope) and jq.
#
#   ORG=<your-test-org> ./rollout-callers.sh <tag> [audit|warn|block] [repo ...]
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
TAG="${1:?usage: rollout-callers.sh <tag> [mode] [repo ...]}"
MODE="${2:-block}"
shift; [[ $# -gt 0 ]] && shift
case "$MODE" in audit|warn|block) ;; *) echo "mode must be audit, warn or block" >&2; exit 1 ;; esac
CENTRAL="security-workflows"
BRANCH="security-gate"
FILE=".github/workflows/security.yml"

sha=$(gh api "repos/$ORG/$CENTRAL/commits/$TAG" --jq .sha)
echo "$CENTRAL $TAG = $sha"
content=$(sed -e "s|@ORG@|$ORG|g" -e "s|@SHA@|$sha|g" -e "s|@TAG@|$TAG|g" -e "s|@MODE@|$MODE|g" \
  "$HERE/caller.yml.template")

repos=("$@")
if [[ ${#repos[@]} -eq 0 ]]; then
  mapfile -t repos < <(gh api --paginate "orgs/$ORG/repos?per_page=100" \
    --jq ".[] | select(.archived | not) | select(.name != \"$CENTRAL\") | .name")
fi

for r in "${repos[@]}"; do
  main=$(gh api "repos/$ORG/$r" --jq .default_branch)
  current=$(gh api "repos/$ORG/$r/contents/$FILE?ref=$main" --jq .content 2>/dev/null | base64 -d 2>/dev/null || true)
  if [[ "$current" == "$content" ]]; then echo "skip $r: caller already at $TAG ($MODE)"; continue; fi
  if [[ -n "$(gh pr list -R "$ORG/$r" --head "$BRANCH" --state open --json number --jq '.[].number')" ]]; then
    echo "skip $r: rollout PR already open"; continue
  fi

  base=$(gh api "repos/$ORG/$r/git/ref/heads/$main" --jq .object.sha)
  gh api -X DELETE "repos/$ORG/$r/git/refs/heads/$BRANCH" --silent 2>/dev/null || true
  gh api -X POST "repos/$ORG/$r/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$base" --silent
  args=(-X PUT "repos/$ORG/$r/contents/$FILE" -f branch="$BRANCH"
        -f message="Security gate: $TAG in $MODE mode" -f content="$(base64 <<<"$content" | tr -d "\n")")
  existing=$(gh api "repos/$ORG/$r/contents/$FILE?ref=$BRANCH" --jq .sha 2>/dev/null || true)
  [[ -n "$existing" ]] && args+=(-f sha="$existing")
  gh api "${args[@]}" --silent

  url=$(gh pr create -R "$ORG/$r" --head "$BRANCH" --base "$main" \
    --title "Security gate: $TAG in $MODE mode" \
    --body "Calls $ORG/$CENTRAL at $TAG ($sha) in \`$MODE\` mode. Rolled out by rollout-callers.sh.")
  echo "opened $url"
done
