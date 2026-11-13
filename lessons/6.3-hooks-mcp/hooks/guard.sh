#!/bin/bash
# Managed PreToolUse hook for Claude Code. Install as /etc/claude-code/hooks/guard.sh (root-owned, 755).
# Reads the hook JSON on stdin. Exit 2 blocks the tool call; stderr is the reason Claude sees.
# It is a pattern check on what Claude asked for, not a sandbox: an obfuscated command can get past it.
input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input")
block() { echo "Blocked by org policy (guard.sh): $1" >&2; exit 2; }

case "$tool" in
  Bash)
    cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
    if grep -Eq '(^|[^[:alnum:]_-])git([[:space:]]|$)' <<<"$cmd"; then
      grep -Eq '[[:space:]]push([[:space:]]|$)' <<<"$cmd" &&
        grep -Eq '(--force|--force-with-lease|--mirror|--delete|[[:space:]]-[[:alnum:]]*f[[:alnum:]]*([[:space:]]|$)|[[:space:]]\+[^[:space:]]+)' <<<"$cmd" &&
        block "force push, mirror push and branch deletion are not allowed"
      { grep -Eq -- '--no-verify' <<<"$cmd" ||
        grep -Eq '[[:space:]]commit([[:space:]].*)?[[:space:]]-[[:alnum:]]*n[[:alnum:]]*([[:space:]]|$)' <<<"$cmd"; } &&
        block "--no-verify skips the repo's hooks"
    fi
    grep -Eq '(^|[[:space:]/])\.env(\.[[:alnum:]]+)?([[:space:]"'"'"';|&)]|$)' <<<"$cmd" &&
      block "commands that name a .env file are not allowed"
    ;;
  Edit|Write|MultiEdit|NotebookEdit)
    path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
    [[ "$path" == */.github/workflows/* || "$path" == .github/workflows/* ]] &&
      block "workflow files change only through a reviewed PR written by a person"
    ;;
  Read)
    path=$(jq -r '.tool_input.file_path // empty' <<<"$input")
    [[ "$(basename -- "$path")" =~ ^\.env(\..+)?$ ]] && block ".env files are not readable by the agent"
    ;;
esac
exit 0
