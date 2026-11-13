#!/usr/bin/env bash
# Set the tier and owner-team custom properties on one repo.
#   ORG=<your-test-org> ./set-tier.sh <repo> <critical|standard|sandbox> <owner-team>
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
repo="${1:?repo}"; tier="${2:?tier}"; team="${3:?owner-team}"
jq -n --arg r "$repo" --arg t "$tier" --arg o "$team" '{repository_names: [$r], properties: [
  {property_name: "tier", value: $t}, {property_name: "owner-team", value: $o}]}' \
  | gh api -X PATCH "orgs/$ORG/properties/values" --input - --silent
echo "$repo tier=$tier owner-team=$team"
