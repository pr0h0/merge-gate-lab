#!/usr/bin/env bash
# Wait for the required check on each fleet repo's PR from <branch>, then squash-merge it.
# Code-owned files need a security team review; in a one-person lab the owner merges with
# --admin, which rule-suites log as a bypass. In a real org, drop --admin and get the review.
#
#   ORG=<your-test-org> ./merge-fleet-prs.sh <branch> [repo ...]
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
BRANCH="${1:?usage: merge-fleet-prs.sh <branch> [repo ...]}"
shift
repos=("$@")
if [[ ${#repos[@]} -eq 0 ]]; then
  mapfile -t repos < <(gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name')
fi
for r in "${repos[@]}"; do
  n=$(gh pr list -R "$ORG/$r" --head "$BRANCH" --state open --json number --jq '.[0].number')
  [[ -n "$n" ]] || continue
  # A PR opened seconds ago has no checks yet, and `gh pr checks` treats that as a failure.
  for _ in {1..12}; do
    gh pr checks "$n" -R "$ORG/$r" --required 2>&1 | grep -qE 'no (required )?checks reported' || break
    sleep 10
  done
  if gh pr checks "$n" -R "$ORG/$r" --watch --required >/dev/null; then
    gh pr merge "$n" -R "$ORG/$r" --squash --admin --delete-branch && echo "merged $r#$n"
  else
    echo "NOT merged $r#$n: required check failed"
  fi
done
