#!/usr/bin/env bash
# Lesson 8.3: a small markdown report of security program metrics from real fleet data.
#   gate        per PR: did the last `security / gate` run pass, and what happened to the PR
#               (merged, merged over a failed gate, closed); exceptions in force
#   merge time  median PR created -> merged, Dependabot vs people, and gate run time
#   dependabot  alert time-to-fix (created_at -> fixed_at) and open high/critical alerts per tier
#   bypasses    ruleset bypasses per month and how many have a written reason (8.1 bypasses.sh)
#   coverage    % of repos passing each 8.2 coverage check (caller, CODEOWNERS, events, secrets, dependabot.yml)
# Writes $OUT/metrics.md (and the raw JSON next to it), prints the report.
# Needs gh, jq, yq (for the exception register). bypasses.sh takes a few minutes; pass
# BYPASSES=<bypasses.json> to reuse a saved one.
#   ORG=<your-test-org> ./metrics.sh
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
H="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-metrics-out}"; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
export ORG

repos=$(gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name')
tiers=$(gh api "orgs/$ORG/properties/values" --jq 'map({(.repository_name): ((.properties[] | select(.property_name == "tier") | .value) // "none")}) | add')

# One line per PR with the conclusion of `security / gate` on its last commit.
# ponytail: only the last commit's check is read; a PR that failed, got fixed and passed counts as a pass.
: > "$OUT/prs.jsonl"
for r in $repos; do
  gh pr list -R "$ORG/$r" --state all -L 500 --json number,state,createdAt,mergedAt,author,headRefOid \
    --jq '.[] | @json' | while read -r p; do
      sha=$(jq -r .headRefOid <<<"$p")
      gate=$(gh api "repos/$ORG/$r/commits/$sha/check-runs?check_name=security%20%2F%20gate" \
        --jq '[.check_runs[].conclusion][0] // "none"' 2>/dev/null || echo none)
      jq -c --arg repo "$r" --arg gate "$gate" '{repo: $repo, n: .number, state, createdAt, mergedAt,
        bot: ((.author.is_bot == true) or (.author.login | test("\\[bot\\]$|^app/"))), gate: $gate}' <<<"$p" >> "$OUT/prs.jsonl"
    done
done

# Gate run durations (fleet callers and the gate's self-test).
for r in $repos; do
  wf=security.yml; [[ $r == security-workflows ]] && wf=self-test.yml
  gh api "repos/$ORG/$r/actions/workflows/$wf/runs?event=pull_request&per_page=100" \
    --jq '.workflow_runs[] | select(.conclusion == "success" or .conclusion == "failure")
          | ((.updated_at | fromdate) - (.run_started_at | fromdate))' 2>/dev/null || true
done > "$OUT/gate-seconds.txt"

# Dependabot alerts, all states.
for r in $repos; do
  gh api --paginate "repos/$ORG/$r/dependabot/alerts?state=open,fixed,dismissed,auto_dismissed&per_page=100" \
    --jq ".[] | {repo: \"$r\", state, severity: .security_advisory.severity, created_at, fixed_at, dismissed_at,
                 package: .dependency.package.name}" 2>/dev/null || true
done | jq -s . > "$OUT/alerts.json"

# Reuse the 8.1 and 8.2 scripts.
OUT="$OUT/register.json" "$H/8.1-exceptions-bypasses/exceptions-register.sh" > "$OUT/exceptions.txt" || true
if [[ -n "${BYPASSES:-}" ]]; then cp "$BYPASSES" "$OUT/bypasses.json"
else OUT="$OUT/bypasses.json" "$H/8.1-exceptions-bypasses/bypasses.sh" > "$OUT/bypasses.txt" || true; fi
"$H/8.2-drift-schedule/gate/audit/check-coverage.sh" > "$OUT/coverage.txt" || true

median='sort | if length == 0 then null else .[(length / 2 | floor)] end'
mins='if . == null then "-" else "\(. / 6 | floor / 10) min" end'

{
  echo "# Security metrics for \`$ORG\` ($(date -u +%F))"
  echo
  echo "## Gate outcomes per PR (last commit)"
  echo
  jq -rs '
    def row(name; f): [.[] | select(f)] | "| \(name) | \(map(select(.gate == "success")) | length) | \(map(select(.gate == "failure")) | length) | \(map(select(.gate == "none" or .gate == "startup_failure" or .gate == "cancelled")) | length) |";
    "| PRs | gate passed | gate failed | no gate result |", "|---|---|---|---|",
    row("all"; true), row("merged"; .state == "MERGED"), row("closed unmerged"; .state == "CLOSED"), row("open"; .state == "OPEN"),
    "",
    "Gate fail rate on PRs with a result: \([.[] | select(.gate == "success" or .gate == "failure")] | if length == 0 then "-" else "\((map(select(.gate == "failure")) | length) * 100 / length | floor)% of \(length)" end).",
    "Merged although the last gate run failed (needed an admin bypass): \([.[] | select(.state == "MERGED" and .gate == "failure")] | length)."' "$OUT/prs.jsonl"
  echo "Exceptions in force (accepted findings, the closest thing to a false-positive count): $(jq length "$OUT/register.json" 2>/dev/null || echo '?'), $(jq -r 'group_by(.status) | map("\(.[0].status) \(length)") | join(", ")' "$OUT/register.json" 2>/dev/null)."
  echo
  echo "## Time to merge"
  echo
  jq -rs "
    def ttm: [.[] | select(.mergedAt) | ((.mergedAt | fromdate) - (.createdAt | fromdate))] | $median | $mins;
    \"| PR author | merged | median created -> merged |\", \"|---|---|---|\",
    \"| people | \([.[] | select(.mergedAt and (.bot | not))] | length) | \([.[] | select(.bot | not)] | ttm) |\",
    \"| bots (Dependabot) | \([.[] | select(.mergedAt and .bot)] | length) | \([.[] | select(.bot)] | ttm) |\"" "$OUT/prs.jsonl"
  echo
  echo "Gate run time (PR runs): median $(jq -s "$median" "$OUT/gate-seconds.txt") s, slowest $(jq -s 'max' "$OUT/gate-seconds.txt") s, over $(wc -l < "$OUT/gate-seconds.txt") runs."
  echo
  echo "## Dependabot alerts"
  echo
  jq -r "
    \"Fixed: \([.[] | select(.state == \"fixed\")] | length), median time to fix \([.[] | select(.fixed_at) | ((.fixed_at | fromdate) - (.created_at | fromdate))] | $median | $mins). Dismissed: \([.[] | select(.state | test(\"dismissed\"))] | length). Open: \([.[] | select(.state == \"open\")] | length).\"" "$OUT/alerts.json"
  echo
  echo "| Tier | repos | open high/critical alerts |"; echo "|---|---|---|"
  jq -r --argjson t "$tiers" '. as $a | ($t | to_entries | group_by(.value))[] | .[0].value as $tier | map(.key) as $rs
    | "| \($tier) | \($rs | length) | \([$a[] | select(.state == "open" and (.severity == "high" or .severity == "critical") and (.repo | IN($rs[])))] | length) |"' "$OUT/alerts.json"
  echo
  echo "## Ruleset bypasses"
  echo
  if [[ -s "$OUT/bypasses.json" ]]; then
    echo "| Month | bypasses | with a written reason |"; echo "|---|---|---|"
    jq -r 'group_by(.at[:7]) | .[] | "| \(.[0].at[:7]) | \(length) | \(map(select(.reason)) | length) |"' "$OUT/bypasses.json"
    echo
    echo "The rule insights API keeps one month; save each month's bypasses.json to count further back."
  else echo "Could not read bypasses."; fi
  echo
  echo "## Coverage"
  echo
  echo "| Control | repos passing | % |"; echo "|---|---|---|"
  awk '{ seen[$3]++; if ($1 == "PASS") ok[$3]++ } END { for (c in seen) printf "| %s | %d of %d | %d%% |\n", c, ok[c], seen[c], 100 * ok[c] / seen[c] }' "$OUT/coverage.txt" | sort
} > "$OUT/metrics.md"
cat "$OUT/metrics.md"
