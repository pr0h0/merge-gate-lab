#!/usr/bin/env bash
# Apply one repo ruleset to every repo in the org, matched by its name: create it where it is
# missing, overwrite it where it exists. Safe to rerun. Needs gh (org owner) and jq.
#
#   ORG=<your-test-org> ./apply-baseline.sh                       # baseline.json, all repos
#   ORG=<your-test-org> ./apply-baseline.sh other.json            # another ruleset file
#   ORG=<your-test-org> ./apply-baseline.sh baseline.json repo1   # only some repos
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
FILE="${1:-$(dirname "$0")/baseline.json}"
shift || true
NAME=$(jq -er .name "$FILE")

repos=("$@")
if [[ ${#repos[@]} -eq 0 ]]; then
  # Archived repos are read-only, so they are skipped.
  mapfile -t repos < <(gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name')
fi

for r in "${repos[@]}"; do
  # includes_parents=false: only rulesets that live in the repo, not org rulesets.
  id=$(gh api "repos/$ORG/$r/rulesets?includes_parents=false&per_page=100" \
    | jq -r --arg n "$NAME" '.[] | select(.name == $n) | .id')
  if [[ -z "$id" ]]; then
    gh api -X POST "repos/$ORG/$r/rulesets" --input "$FILE" --silent
    echo "created $NAME on $r"
  else
    gh api -X PUT "repos/$ORG/$r/rulesets/$id" --input "$FILE" --silent
    echo "updated $NAME on $r (id $id)"
  fi
done
