#!/usr/bin/env bash
# Lesson 5.2: put a repo-level Actions event policy on every repo in the org that allows every
# event except pull_request_target and workflow_run (event-policy.json). Replaces a policy with
# the same name; leaves other policies alone. Repo-level policies work on Free public repos;
# org-level ones need Team (403 "Upgrade to GitHub Team"). Repo admins can delete them.
#
#   ORG=<your-test-org> ./apply-event-policy.sh [repo ...]
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
FILE="$(cd "$(dirname "$0")" && pwd)/event-policy.json"
name=$(jq -r .name "$FILE")
repos=("$@")
if [[ ${#repos[@]} -eq 0 ]]; then
  mapfile -t repos < <(gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name')
fi
for r in "${repos[@]}"; do
  id=$(gh api "repos/$ORG/$r/actions/policies" --jq ".policies[] | select(.name == \"$name\") | .id")
  if [[ -n "$id" ]]; then
    gh api -X PUT "repos/$ORG/$r/actions/policies/$id" --input "$FILE" --silent && echo "updated $r ($id)"
  else
    gh api -X POST "repos/$ORG/$r/actions/policies" --input "$FILE" --jq '"created \(.source) (\(.id)) \(.enforcement)"'
  fi
done
