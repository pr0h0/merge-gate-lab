#!/bin/bash
# shellcheck disable=SC2015 # ok() always succeeds, so "A && ok || bad" is safe here
# Checks that this machine's Claude Code managed settings file is the one the org deployed.
# Usage: check-managed.sh <expected-managed-settings.json>
# Exit 0 = all PASS. Run it from your device management tool and report FAILs centrally.
set -u
expected=${1:?usage: check-managed.sh <expected-managed-settings.json>}
case "$(uname -s)" in
  Darwin) dir="/Library/Application Support/ClaudeCode"; st() { stat -f '%u %Lp' "$1"; } ;;
  *)      dir=/etc/claude-code;                          st() { stat -c '%u %a' "$1"; } ;;
esac
f="$dir/managed-settings.json"; fail=0
ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1"; fail=1; }
[ -f "$f" ] && ok "file exists: $f" || { bad "file missing: $f"; exit 1; }
for p in "$dir" "$f"; do
  read -r uid mode < <(st "$p")
  [ "$uid" = 0 ] && ok "owned by root: $p" || bad "owner uid $uid, not root: $p"
  (( (8#$mode & 8#022) == 0 )) && ok "not group/world writable ($mode): $p" || bad "group/world writable ($mode): $p"
done
jq -e 'type == "object"' "$f" >/dev/null 2>&1 && ok "valid JSON object" || bad "not a JSON object (Claude Code refuses to start)"
if [ "$(jq -S . "$f" 2>/dev/null)" = "$(jq -S . "$expected")" ]; then ok "content matches $expected"
else bad "content differs from $expected:"; diff <(jq -S . "$expected") <(jq -S . "$f" 2>/dev/null) | sed 's/^/     /'; fi
if [ -d "$dir/managed-settings.d" ]; then
  for d in "$dir"/managed-settings.d/*.json; do [ -e "$d" ] && echo "INFO drop-in present (merged after the main file): $d"; done
fi
exit $fail
