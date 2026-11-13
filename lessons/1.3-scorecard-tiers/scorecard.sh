#!/usr/bin/env bash
# Run OpenSSF Scorecard against every repo in an org and print the checks that matter
# to the people who own the org. Raw JSON (with details) goes to $OUT/<repo>.json.
# Needs gh, jq and docker. The token comes from gh and is never printed.
#
#   ORG=<your-test-org> ./scorecard.sh               # writes ./scorecard/
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
OUT="${OUT:-scorecard}"
SCORECARD=ghcr.io/ossf/scorecard:v5.6.0
MATTER=(Dangerous-Workflow Token-Permissions Branch-Protection Code-Review Pinned-Dependencies
        Dependency-Update-Tool Vulnerabilities Binary-Artifacts SAST)
mkdir -p "$OUT"
GITHUB_AUTH_TOKEN="$(gh auth token)"; export GITHUB_AUTH_TOKEN   # passed by name, not on the command line

while read -r name; do
  docker run --rm -e GITHUB_AUTH_TOKEN "$SCORECARD" --repo="github.com/$ORG/$name" \
    --format=json --show-details > "$OUT/$name.json" 2>"$OUT/$name.log" \
    || { echo "scorecard failed for $name, see $OUT/$name.log" >&2; continue; }
  echo "scored $name" >&2
done < <(gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name')

# One row per repo: overall score, then the score of each check that matters (-1 = not applicable).
{ printf 'REPO\tSCORE\t%s\n' "$(IFS=$'\t'; echo "${MATTER[*]}")"
  for f in "$OUT"/*.json; do
    jq -r --args '[(.repo.name | split("/") | last), .score] +
      [.checks as $c | $ARGS.positional[] | . as $n | ($c[] | select(.name == $n) | .score) // "?"] | @tsv' \
      "${MATTER[@]}" < "$f"
  done; } | column -t -s $'\t'
