#!/usr/bin/env bash
# Apply the org's Actions policy from actions-policy.json: SHA pinning required, and only
# GitHub-owned actions, verified creators and the listed patterns allowed. Run list-actions.sh
# first: every workflow that uses something unpinned or not allowed fails at "Set up job".
#
#   ORG=<your-test-org> ./apply-actions-policy.sh [policy.json]
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
FILE="${1:-$(cd "$(dirname "$0")" && pwd)/actions-policy.json}"
jq '.permissions' "$FILE" | gh api -X PUT "orgs/$ORG/actions/permissions" --input - --silent
jq '.selected_actions' "$FILE" | gh api -X PUT "orgs/$ORG/actions/permissions/selected-actions" --input - --silent
gh api "orgs/$ORG/actions/permissions" --jq '"allowed_actions=\(.allowed_actions) sha_pinning_required=\(.sha_pinning_required)"'
gh api "orgs/$ORG/actions/permissions/selected-actions" --jq '"github_owned=\(.github_owned_allowed) verified=\(.verified_allowed) patterns=\(.patterns_allowed | join(","))"'
