#!/usr/bin/env bash
# Lesson 9.1: gather the capstone evidence into evidence/ and write evidence/summary.md.
# It reruns the course's own scripts; nothing here changes the org.
#   audit/          8.2 fleet-audit.sh: org settings, baseline drift, coverage, agent guardrails,
#                   exception register, inventory (after), bypasses of the last day
#   inventory-diff  0.3 before.json vs the inventory now, per repo and per setting
#   scan/           1.2 fleet-scan.sh (zizmor, gitleaks, semgrep) now, compared with the saved one
#   blocked-prs     closed PRs whose last `security / gate` run failed, with the gate's messages
#   managed-settings.json + your note (6.1)
# Exits 1 if a required piece is missing or the audit found drift.
#
#   ORG=<your-test-org> BEFORE=0.3-inventory/before.json BEFORE_SCAN=<saved 1.2 summary.json> \
#     MANAGED=6.1-managed-settings/managed-settings.json NOTE=my-managed-note.md ./9.1-capstone/collect-evidence.sh
#   SKIP_SCAN=1 reuses evidence/scan/summary.json instead of scanning again.
set -uo pipefail
: "${ORG:?set ORG=<your-org>}"
L="$(cd "$(dirname "$0")/.." && pwd)"
E="${OUT:-evidence}"; mkdir -p "$E"; E="$(cd "$E" && pwd)"
BEFORE="${BEFORE:-$L/0.3-inventory/before.json}"
MANAGED="${MANAGED:-$L/6.1-managed-settings/managed-settings.json}"
export ORG
missing=(); ok() { printf '| %s | %s | %s |\n' "$1" "$2" "$3" >> "$E/checklist.md"; [[ $2 == yes ]] || missing+=("$1"); }
: > "$E/checklist.md"

echo "1/4 fleet audit (a few minutes)" >&2
OUT="$E/audit" "$L/8.2-drift-schedule/gate/audit/fleet-audit.sh" > /dev/null; audit_rc=$?

echo "2/4 inventory diff" >&2
if [[ -f "$BEFORE" ]]; then
  cp "$BEFORE" "$E/inventory-before.json"
  jq -r --slurpfile a "$E/audit/inventory.json" '
    . as $b | ($b.repos | map({(.name): .}) | add) as $old
    | "| Repo | Setting | Before | After |", "|---|---|---|---|",
      ($b.settings | to_entries[] | select(.value != $a[0].settings[.key]) | "| (org) | \(.key) | \(.value) | \($a[0].settings[.key]) |"),
      ($a[0].repos[] | .name as $n | to_entries[]
        | select(.key != "pushed_at" and .key != "name" and ($old[$n][.key] | tojson) != (.value | tojson))
        | "| \($n) | \(.key) | \(if $old[$n] == null then "(new repo)" else ($old[$n][.key] | tojson) end) | \(.value | tojson) |")' \
    "$E/inventory-before.json" > "$E/inventory-diff.md"
  ok "Inventory before and after" yes "$(grep -c '^| [a-z(]' "$E/inventory-diff.md") settings changed, inventory-diff.md"
else ok "Inventory before and after" no "no before inventory at $BEFORE (set BEFORE=)"; fi

ok "Baseline ruleset, zero drift" "$( [[ $(cat "$E/audit/baseline.txt") == *MISSING* || $(cat "$E/audit/baseline.txt") == *CHANGED* ]] && echo no || echo yes)" \
  "$(grep -c '^OK' "$E/audit/baseline.txt") of $(grep -cE '^(OK|CHANGED|MISSING)' "$E/audit/baseline.txt") repos OK, audit/baseline.txt"
cp "$L/3.1-reusable-gate/baseline.json" "$E/baseline.json"

echo "3/4 fleet scan" >&2
if [[ -z "${SKIP_SCAN:-}" ]]; then OUT="$E/scan" "$L/1.2-fleet-scan/fleet-scan.sh" > "$E/scan.txt" 2>/dev/null; fi
if [[ -f "${BEFORE_SCAN:-}" && -f "$E/scan/summary.json" ]]; then
  cp "$BEFORE_SCAN" "$E/scan-before.json"
  jq -r --slurpfile a "$E/scan/summary.json" '(.repos | map({(.name): .}) | add) as $b
    | "| Repo | zizmor before | zizmor after | high before | high after |", "|---|---|---|---|---|",
      ($a[0].repos[] | "| \(.name) | \($b[.name].zizmor // "-") | \(.zizmor) | \($b[.name].zizmor_high // "-") | \(.zizmor_high) |")' \
    "$E/scan-before.json" > "$E/zizmor.md"
  ok "zizmor before and after" yes "zizmor.md"
else ok "zizmor before and after" no "need BEFORE_SCAN=<saved summary.json> and a scan"; fi

echo "4/4 blocked PRs, exceptions, managed settings" >&2
: > "$E/blocked-prs.md"
while read -r r; do
  gh pr list -R "$ORG/$r" --state closed -L 200 --json number,title,mergedAt,headRefOid,url \
    --jq '.[] | select(.mergedAt == null) | [.number, .headRefOid, .url, .title] | @tsv' |
  while IFS=$'\t' read -r _ sha url title; do
    id=$(gh api "repos/$ORG/$r/commits/$sha/check-runs?check_name=security%20%2F%20gate" \
      --jq '[.check_runs[] | select(.conclusion == "failure") | .id][0] // empty' 2>/dev/null)
    [[ -z "$id" ]] && continue
    msgs=$(gh api "repos/$ORG/$r/check-runs/$id/annotations" \
      --jq '[.[] | select(.annotation_level == "failure" and (.message | test("exit code") | not)) | "\(.title // ""): \(.message)" | gsub("\\s+"; " ") | .[:160]] | .[:3] | join(" / ")')
    printf -- '- %s %s: %s\n' "$url" "$title" "${msgs:-gate failed}" >> "$E/blocked-prs.md"
  done
done < <(gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name')
ok "PR blocked by the central gate, with reason" "$( [[ -s "$E/blocked-prs.md" ]] && echo yes || echo no)" "$(wc -l < "$E/blocked-prs.md") PRs, blocked-prs.md"
pkg=$( (grep -E ': packages ' "$E/blocked-prs.md"; grep -E ': (lockfile|deps) ' "$E/blocked-prs.md") | head -1)
ok "Dependency PR rejected by the package check" "$( [[ -n "$pkg" ]] && echo yes || echo no)" "${pkg:+$(cut -d' ' -f2 <<<"$pkg")}"

if [[ -f "$MANAGED" ]] && jq -e . "$MANAGED" >/dev/null 2>&1; then
  cp "$MANAGED" "$E/managed-settings.json"
  if [[ -f "${NOTE:-}" ]]; then cp "$NOTE" "$E/managed-settings-note.md"; ok "managed-settings.json with a note" yes "managed-settings.json, managed-settings-note.md"
  else ok "managed-settings.json with a note" no "managed-settings.json copied; write the note and pass NOTE=<file>"; fi
else ok "managed-settings.json with a note" no "no valid JSON at $MANAGED"; fi

n_exp=$(jq '[.[] | select(.expires)] | length' "$E/audit/register.json" 2>/dev/null || echo 0)
ok "Exceptions log with an expiring exception" "$( [[ $n_exp -ge 1 ]] && echo yes || echo no)" "$n_exp entries, audit/exceptions.txt"
ok "Fleet audit clean" "$( [[ $audit_rc == 0 ]] && echo yes || echo no)" "audit/report.md"

{
  echo "# Capstone evidence for \`$ORG\` ($(date -u '+%F %H:%M UTC'))"
  echo
  echo "| Requirement | Present | Where |"; echo "|---|---|---|"
  cat "$E/checklist.md"
  echo
  echo "## Fleet audit"; echo; sed '1,2d' "$E/audit/report.md"
  echo; echo "## What changed since the before inventory"; echo; cat "$E/inventory-diff.md" 2>/dev/null || echo "(no before inventory)"
  echo; echo "## zizmor"; echo; cat "$E/zizmor.md" 2>/dev/null || echo "(no before scan)"
  echo; echo "## PRs the gate blocked"; echo; head -20 "$E/blocked-prs.md"
} > "$E/summary.md"
rm "$E/checklist.md"
cat "$E/summary.md"
[[ ${#missing[@]} == 0 ]] || { echo; echo "MISSING: ${missing[*]}"; exit 1; }
