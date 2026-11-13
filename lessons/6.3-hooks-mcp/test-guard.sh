#!/bin/bash
# Feeds hook JSON to guard.sh and checks the exit code. Usage: ./test-guard.sh [path/to/guard.sh]  (default: hooks/guard.sh)
g=${1:-$(dirname "$0")/hooks/guard.sh}; fail=0
t() { # expected-exit tool json-input
  out=$(printf '{"tool_name":"%s","tool_input":%s}' "$2" "$3" | "$g" 2>&1); rc=$?
  if [ "$rc" = "$1" ]; then r=ok; else r=FAIL; fail=1; fi
  printf '%-4s exit=%s %-6s %s %s\n' "$r" "$rc" "$2" "$3" "${out:+-> $out}"
}
t 2 Bash '{"command":"git push --force origin main"}'
t 2 Bash '{"command":"git push -f"}'
t 2 Bash '{"command":"git -C . push origin +main"}'
t 2 Bash '{"command":"git push --force-with-lease"}'
t 2 Bash '{"command":"git commit --no-verify -m wip"}'
t 2 Bash '{"command":"git commit -nm wip"}'
t 2 Bash '{"command":"cat .env"}'
t 2 Bash '{"command":"cp .env.production /tmp/x"}'
t 0 Bash '{"command":"git push origin feature-1"}'
t 0 Bash '{"command":"git push --follow-tags"}'
t 0 Bash '{"command":"git commit -m \"fix env loading\""}'
t 0 Bash '{"command":"npm test"}'
t 2 Write '{"file_path":"/home/dev/app/.github/workflows/ci.yml","content":"x"}'
t 2 Edit '{"file_path":"/home/dev/app/.github/workflows/release.yml","old_string":"a","new_string":"b"}'
t 0 Edit '{"file_path":"/home/dev/app/src/index.js","old_string":"a","new_string":"b"}'
t 2 Read '{"file_path":"/home/dev/app/.env"}'
t 2 Read '{"file_path":"/home/dev/app/config/.env.local"}'
t 0 Read '{"file_path":"/home/dev/app/README.md"}'
# Known gap: this reads .env without naming it the way the pattern expects
# shellcheck disable=SC2016 # the $(...) is meant literally
t 0 Bash '{"command":"cat $(printf %s .en; printf v)"}'
exit $fail
