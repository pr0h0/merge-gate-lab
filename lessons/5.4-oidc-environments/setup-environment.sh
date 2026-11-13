#!/usr/bin/env bash
# Lesson 5.4: create the `prod` environment on one repo: the security team must approve every
# job that uses it, only `main` may deploy to it, and it holds one environment secret.
# Admins can't skip the rules (can_admins_bypass false; the default is true).
# Required reviewers and branch policies are free on public repos; private repos need a paid plan.
#
#   ORG=<your-test-org> ./setup-environment.sh <repo> [prevent_self_review: true|false]
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
REPO="${1:?usage: setup-environment.sh <repo> [true|false]}"
SELF="${2:-false}"   # true: whoever starts the run can't approve it (needs a second person)
team_id=$(gh api "orgs/$ORG/teams/${TEAM:-security}" --jq .id)
jq -n --argjson t "$team_id" --argjson s "$SELF" '{
  prevent_self_review: $s,
  can_admins_bypass: false,
  reviewers: [{type: "Team", id: $t}],
  deployment_branch_policy: {protected_branches: false, custom_branch_policies: true}}' \
  | gh api -X PUT "repos/$ORG/$REPO/environments/prod" --input - --silent
gh api "repos/$ORG/$REPO/environments/prod/deployment-branch-policies" --jq '.branch_policies[].name' | grep -qx main \
  || gh api -X POST "repos/$ORG/$REPO/environments/prod/deployment-branch-policies" -f name=main -f type=branch --silent
# A fake value, so the demo can show when the job gets it. Never put a real credential in the lab.
gh secret set DEPLOY_NOTE --env prod -R "$ORG/$REPO" --body "lab value, not a credential"
gh api "repos/$ORG/$REPO/environments/prod" --jq '"prod: " + ([.protection_rules[] | .type + (if .prevent_self_review != null then " prevent_self_review=\(.prevent_self_review)" else "" end) + (if .reviewers then " reviewers=" + ([.reviewers[].reviewer | .slug // .login] | join(",")) else "" end)] | join("; ")) + "; branches=" + (.deployment_branch_policy | tostring)'
gh api "repos/$ORG/$REPO/environments/prod/deployment-branch-policies" --jq '"branch policies: " + ([.branch_policies[].name] | join(","))'
