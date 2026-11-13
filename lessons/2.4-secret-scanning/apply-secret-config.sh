#!/usr/bin/env bash
# Create (or update) the code security configuration in secret-config.json, attach it to
# every repo in the org, make it the default for new repos, and print each repo's status.
# Safe to rerun. Needs gh (org owner, admin:org) and jq.
#
#   ORG=<your-test-org> ./apply-secret-config.sh
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
FILE="$(cd "$(dirname "$0")" && pwd)/secret-config.json"
NAME=$(jq -er .name "$FILE")

id=$(gh api "orgs/$ORG/code-security/configurations?per_page=100" \
  | jq -r --arg n "$NAME" '.[] | select(.name == $n) | .id')
if [[ -z "$id" ]]; then
  id=$(gh api -X POST "orgs/$ORG/code-security/configurations" --input "$FILE" --jq .id)
  echo "created configuration $NAME (id $id)"
else
  gh api -X PATCH "orgs/$ORG/code-security/configurations/$id" --input "$FILE" --silent
  echo "updated configuration $NAME (id $id)"
fi

gh api -X POST "orgs/$ORG/code-security/configurations/$id/attach" -f scope=all --silent
gh api -X PUT "orgs/$ORG/code-security/configurations/$id/defaults" -f default_for_new_repos=all \
  --jq '"default for new repos: \(.default_for_new_repos)"'

# Attaching runs in the background; the repo settings can take a few seconds to change.
sleep 5
gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name' | while read -r r; do
  gh api "repos/$ORG/$r" --jq '.security_and_analysis | "\("'"$r"'")  secret_scanning=\(.secret_scanning.status)  push_protection=\(.secret_scanning_push_protection.status)  non_provider=\(.secret_scanning_non_provider_patterns.status)"'
done
