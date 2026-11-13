#!/usr/bin/env bash
# Count what the security gate found, per repo, from the findings artifact of its recent runs.
# Use it while the fleet is in audit mode to see what block mode would do.
#   EVENT=workflow_dispatch (default): the latest full scan per repo (what is already there)
#   EVENT=pull_request LIMIT=20: the last 20 PR runs per repo (how many PRs would have failed)
# Needs gh and jq.
#
#   ORG=<your-test-org> [EVENT=pull_request] [LIMIT=20] ./measure-noise.sh [repo ...]
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
EVENT="${EVENT:-workflow_dispatch}"
LIMIT="${LIMIT:-1}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

repos=("$@")
if [[ ${#repos[@]} -eq 0 ]]; then
  mapfile -t repos < <(gh api --paginate "orgs/$ORG/repos?per_page=100" \
    --jq '.[] | select(.archived | not) | select(.name != "security-workflows") | .name')
fi

printf '%-16s %5s %9s %8s %9s %5s %10s %10s %9s\n' repo runs would-fail semgrep gitleaks deps actionlint exceptions excepted
for r in "${repos[@]}"; do
  mapfile -t runs < <(gh run list -R "$ORG/$r" --workflow security.yml --event "$EVENT" --status completed \
    --limit "$LIMIT" --json databaseId --jq '.[].databaseId')
  for id in "${runs[@]}"; do
    gh run download "$id" -R "$ORG/$r" -n security-gate-findings -D "$tmp/$r/$id" 2>/dev/null || true
  done
  # One array per run. Runs without the artifact (gate versions before v2.0.0) are skipped.
  for id in "${runs[@]}"; do cat "$tmp/$r/$id/findings.json" 2>/dev/null || true; done \
    | jq -rs --arg r "$r" '
        (map(map(select(.excepted == null)))) as $open
        | def count($t): [$open[][] | select(.tool == $t)] | length;
        [$r, length, ($open | map(select(length > 0)) | length),
         count("semgrep"), count("gitleaks"), count("deps"), count("actionlint"), count("exceptions"),
         ([.[][] | select(.excepted != null)] | length)] | @tsv' \
    | awk -F'\t' '{printf "%-16s %5s %9s %8s %9s %5s %10s %10s %9s\n", $1,$2,$3,$4,$5,$6,$7,$8,$9}'
done
