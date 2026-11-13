#!/usr/bin/env bash
# Give the security team write access to every repo and open one PR per repo that adds
# .github/CODEOWNERS from CODEOWNERS.template. Safe to rerun: repos that already have the
# same file on the default branch, or an open rollout PR, are skipped. Needs gh and jq.
#
#   ORG=<your-test-org> ./rollout-codeowners.sh [repo ...]
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
TEAM="${TEAM:-security}"
BRANCH="add-codeowners"
content=$(sed "s|@ORG/|@$ORG/|g" "$HERE/CODEOWNERS.template")

repos=("$@")
if [[ ${#repos[@]} -eq 0 ]]; then
  mapfile -t repos < <(gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name')
fi

for r in "${repos[@]}"; do
  # Code owners must have write access, or GitHub ignores the line.
  gh api -X PUT "orgs/$ORG/teams/$TEAM/repos/$ORG/$r" -f permission=push --silent

  main=$(gh api "repos/$ORG/$r" --jq .default_branch)
  current=$(gh api "repos/$ORG/$r/contents/.github/CODEOWNERS?ref=$main" --jq .content 2>/dev/null | base64 -d 2>/dev/null || true)
  if [[ "$current" == "$content" ]]; then echo "skip $r: CODEOWNERS already up to date"; continue; fi
  if [[ -n "$(gh pr list -R "$ORG/$r" --head "$BRANCH" --state open --json number --jq '.[].number')" ]]; then
    echo "skip $r: rollout PR already open"; continue
  fi

  sha=$(gh api "repos/$ORG/$r/git/ref/heads/$main" --jq .object.sha)
  gh api -X DELETE "repos/$ORG/$r/git/refs/heads/$BRANCH" --silent 2>/dev/null || true
  gh api -X POST "repos/$ORG/$r/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$sha" --silent
  args=(-X PUT "repos/$ORG/$r/contents/.github/CODEOWNERS" -f branch="$BRANCH"
        -f message="Add CODEOWNERS for security-relevant files" -f content="$(base64 <<<"$content" | tr -d "\n")")
  existing=$(gh api "repos/$ORG/$r/contents/.github/CODEOWNERS?ref=$BRANCH" --jq .sha 2>/dev/null || true)
  [[ -n "$existing" ]] && args+=(-f sha="$existing")
  gh api "${args[@]}" --silent

  url=$(gh pr create -R "$ORG/$r" --head "$BRANCH" --base "$main" \
    --title "Add CODEOWNERS for security-relevant files" \
    --body "Workflows, dependency manifests, lockfiles, Dockerfiles, IaC and auth code need a review from @$ORG/$TEAM. Rolled out by rollout-codeowners.sh.")
  echo "opened $url"
done
