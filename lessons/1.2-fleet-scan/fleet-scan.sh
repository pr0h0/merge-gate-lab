#!/usr/bin/env bash
# Scan every repo in an org: gitleaks over full history (all refs, including PR refs),
# zizmor over the workflows and Semgrep over the code on the default branch.
# Writes raw outputs plus summary.json and prints counts per repo per tool.
# Needs gh (logged in, read access to the repos), git, jq and docker.
#
#   ORG=<your-test-org> ./fleet-scan.sh                 # writes ./scan/
#   ORG=<your-test-org> OUT=scan-2026-11 SEMGREP_CONFIG=p/javascript ./fleet-scan.sh
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
OUT="$(mkdir -p "${OUT:-scan}" && cd "${OUT:-scan}" && pwd)"
SEMGREP_CONFIG="${SEMGREP_CONFIG:-p/default}"
GITLEAKS=zricethezav/gitleaks:v8.30.1
ZIZMOR=ghcr.io/zizmorcore/zizmor:1.32.0
SEMGREP=semgrep/semgrep:1.185.0
mkdir -p "$OUT/mirror" "$OUT/src" "$OUT/raw"
as_me=(--rm --user "$(id -u):$(id -g)")
git_gh=(-c credential.helper= -c 'credential.helper=!gh auth git-credential')

rows=()
while read -r name; do
  m="$OUT/mirror/$name.git"; s="$OUT/src/$name"; r="$OUT/raw/$name"
  # A mirror has every ref GitHub serves, including refs/pull/*: commits from closed PRs live there.
  if [[ -d "$m" ]]; then git "${git_gh[@]}" --git-dir "$m" remote update --prune >/dev/null 2>&1
  else git "${git_gh[@]}" clone -q --mirror "https://github.com/$ORG/$name.git" "$m"; fi
  rm -rf "$s"; mkdir -p "$s"
  git --git-dir "$m" archive HEAD | tar -x -C "$s"   # the default branch as it is today

  # --redact keeps the secret values out of the report; the report itself is still sensitive.
  docker run "${as_me[@]}" -v "$m:/repo:ro" -v "$OUT/raw:/out" "$GITLEAKS" \
    git /repo --redact --no-banner --exit-code 0 --log-level error \
    --report-format json --report-path "/out/$name.gitleaks.json"
  # Offline: no GitHub API calls. Set GH_TOKEN in the container to add the online audits.
  docker run "${as_me[@]}" -v "$s:/src:ro" "$ZIZMOR" --offline --format json /src \
    > "$r.zizmor.json" 2>"$r.zizmor.log" || true
  docker run "${as_me[@]}" -v "$s:/src:ro" -e HOME=/tmp "$SEMGREP" \
    semgrep scan --config "$SEMGREP_CONFIG" --metrics=off --json --quiet /src \
    > "$r.semgrep.json" 2>"$r.semgrep.log" || true

  # A second, dumber check: files that should never be committed, in any commit on any ref.
  # It catches what gitleaks misses when a token's entropy is too low for its generic rule.
  git --git-dir "$m" log --all --name-only --format= | grep -E '(^|/)(\.env(\..*)?|id_rsa|id_ed25519|.*\.pem|.*\.p12)$' \
    | sort -u > "$r.risky-files.txt" || true

  rows+=("$(jq -nc --arg name "$name" --rawfile rf "$r.risky-files.txt" \
    --slurpfile g "$r.gitleaks.json" --slurpfile z "$r.zizmor.json" --slurpfile sg "$r.semgrep.json" '{
      name: $name,
      secrets_in_history: ($g[0] | length),
      secret_files: ($g[0] | map(.File) | unique),
      risky_files_in_history: ($rf | split("\n") | map(select(length > 0))),
      zizmor: ($z[0] | length),
      zizmor_high: ($z[0] | map(select(.determinations.severity == "High")) | length),
      semgrep_code: ($sg[0].results | map(select(.path | startswith("/src/.github/") | not)) | length),
      semgrep_workflows: ($sg[0].results | map(select(.path | startswith("/src/.github/"))) | length),
      semgrep_blocking: ($sg[0].results | map(select(.extra.severity == "ERROR")) | length),
      scan_errors: ($sg[0].errors | map(select(.level == "error")) | length) }')")
  echo "scanned $name" >&2
done < <(gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name')

printf '%s\n' "${rows[@]}" | jq -s --arg org "$ORG" --arg cfg "$SEMGREP_CONFIG" \
  '{org: $org, generated_at: (now | todate), semgrep_config: $cfg, repos: .}' > "$OUT/summary.json"

jq -r '["REPO","GITLEAKS","RISKY_FILES","ZIZMOR","ZIZMOR_HIGH","SEMGREP_CODE","SEMGREP_WF","SEMGREP_ERROR","SCAN_ERR"],
  (.repos[] | [.name, .secrets_in_history, (.risky_files_in_history | length), .zizmor, .zizmor_high,
    .semgrep_code, .semgrep_workflows, .semgrep_blocking, .scan_errors])
  | @tsv' "$OUT/summary.json" | column -t -s $'\t'
echo; echo "raw outputs in $OUT/raw, summary in $OUT/summary.json"
