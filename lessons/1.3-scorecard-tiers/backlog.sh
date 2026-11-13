#!/usr/bin/env bash
# Build a risk-ranked backlog: one row per problem per repo, scored as
#   severity x tier weight   (tier from the org's `tier` custom property)
# except leaked secrets, which always get the top weight: a live credential's reach
# doesn't depend on the tier of the repo it leaked from.
# from the fleet scan (lesson 1.2) and the Scorecard run (scorecard.sh). Prints markdown.
#
#   ORG=<your-test-org> SCAN=../1.2-fleet-scan/scan SCORECARD=scorecard ./backlog.sh > backlog.md
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
SCAN="${SCAN:-../1.2-fleet-scan/scan}"
SCORECARD="${SCORECARD:-scorecard}"

# Tier weights and severities are policy: change them here, not in the jq below.
weights='{"critical": 3, "standard": 2, "sandbox": 1}'
props=$(gh api --paginate "orgs/$ORG/properties/values?per_page=100" --jq '.[] |
  {(.repository_name): (.properties | map({(.property_name): .value}) | add)}' | jq -s 'add // {}')

items=()
for summary in $(jq -r '.repos[].name' "$SCAN/summary.json"); do
  r="$SCAN/raw/$summary"; sc="$SCORECARD/$summary.json"; [[ -f "$sc" ]] || sc=/dev/null
  items+=("$(jq -nc --arg repo "$summary" --argjson props "$props" --argjson w "$weights" \
    --slurpfile g "$r.gitleaks.json" --rawfile rf "$r.risky-files.txt" \
    --slurpfile z "$r.zizmor.json" --slurpfile s "$r.semgrep.json" --slurpfile c "$sc" '
    ($props[$repo].tier // "?") as $tier | ($w[$tier] // 2) as $tw |
    [ # 1. Secrets in history: rotate first, whatever else is wrong.
      (($g[0] | map(.File)) + ($rf | split("\n") | map(select(length > 0))) | unique[]
        | {sev: 10, source: "history", finding: "Secret or key file in git history: \(.) (rotate it)"}),
      # 2. Workflow findings (zizmor), grouped by audit.
      ($z[0] | group_by(.ident)[] | {ident: .[0].ident, n: length,
        s: (map(.determinations.severity) | if index("High") then "High" elif index("Medium") then "Medium" else "Low" end)}
        | select(.s != "Low")
        | {sev: (if .s == "High" then 5 else 3 end), source: "zizmor",
           finding: "\(.ident) (\(.s), \(.n)x) in workflows"}),
      # 3. Code findings (Semgrep), skipping .github/: zizmor already covers workflows.
      ($s[0].results | map(select(.path | startswith("/src/.github/") | not))
        | group_by(.check_id)[] | select(.[0].extra.severity != "INFO")
        | {sev: (if .[0].extra.severity == "ERROR" then 4 else 2 end), source: "semgrep",
           finding: "\(.[0].check_id | split(".") | last) at \(map("\(.path | ltrimstr("/src/")):\(.start.line)") | join(", "))"}),
      # 4. Scorecard checks the scanners above do not cover, when they score below 5.
      ($c[0].checks // [] | .[]
        | select(.name | IN("Branch-Protection","Code-Review","Dependency-Update-Tool","Pinned-Dependencies","Vulnerabilities","Binary-Artifacts","SAST"))
        | select(.score >= 0 and .score < 5)
        | {sev: 3, source: "scorecard", finding: "\(.name) \(.score)/10: \(.reason)"})
    ] | map(. + {repo: $repo, tier: $tier, owner: ($props[$repo]["owner-team"] // "?"),
                 score: (.sev * (if .source == "history" then ($w | [.[]] | max) else $tw end))})')")
done

printf '%s\n' "${items[@]}" | jq -rs 'add | sort_by(-.score, .repo) | to_entries |
  "| # | Score | Repo | Tier | Owner | Source | Finding |", "|---|---|---|---|---|---|---|",
  (.[] | .key as $i | .value | "| \($i + 1) | \(.score) | \(.repo) | \(.tier) | \(.owner) | \(.source) | \(.finding | gsub("\\|"; "/")) |")'
