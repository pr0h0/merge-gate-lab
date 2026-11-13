#!/usr/bin/env bash
# Lesson 5.1: give the lab's ci.yml and triage.yml least-privilege tokens. Run in a repo
# checkout (or through 4.1-dependabot/fleet-pr.sh). Safe to rerun.
#   - `permissions: {}` at the top: every job starts with no token permissions
#   - ci.yml job `test`: `contents: read` (all it needs to check out and run tests)
#   - every actions/checkout step: `persist-credentials: false`
# triage.yml only echoes, so its job gets nothing.
set -euo pipefail
W=.github/workflows
for f in "$W/ci.yml" "$W/triage.yml"; do
  [[ -f "$f" ]] || continue
  grep -q '^permissions:' "$f" || sed -i 's/^jobs:/permissions: {}\n\njobs:/' "$f"
  # checkout: add persist-credentials: false as the first `with:` key (or add a `with:`).
  grep -q 'persist-credentials: false' "$f" || ! grep -q 'uses: actions/checkout@' "$f" || {
    awk '
      /uses: actions\/checkout@/ { print; co = 1; ind = substr($0, 1, index($0, "-") - 1); next }
      co && /^[[:space:]]+with:[[:space:]]*$/ { print; print ind "    persist-credentials: false"; co = 0; next }
      co { print ind "  with:"; print ind "    persist-credentials: false"; co = 0 }
      { print }
    ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  }
done
f="$W/ci.yml"
if [[ -f "$f" ]] && ! grep -q '^    permissions:' "$f"; then
  sed -i '0,/^    runs-on: /s//    permissions:\n      contents: read\n&/' "$f"
fi
