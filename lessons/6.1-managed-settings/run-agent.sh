#!/bin/bash
# Runs a command on a throwaway "developer machine" (docker) with an org policy installed.
#   POLICY=<dir>   its managed-settings.json, managed-settings.d/, managed-mcp.json and hooks/ are
#                  copied to /etc/claude-code (root-owned, read-only for the developer); the whole
#                  dir is also visible read-only at /policy
#   PROJECT=<dir>  copied to ~/proj, the working directory (default: none)
#   AS=root        run as root with the extra privileges bubblewrap needs inside docker (6.2)
#   PRIV=1         with AS=root: use --privileged instead (needed for CLAUDE_CODE_SUBPROCESS_ENV_SCRUB)
# Model access, only if a step needs it: export ANTHROPIC_API_KEY, or on Linux keep ~/.claude/.credentials.json
# (mounted read-only, never copied). Example:
#   POLICY=6.1-managed-settings PROJECT=6.1-managed-settings/demo 6.1-managed-settings/run-agent.sh claude doctor
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
img=merge-gate-lab/claude-code:2.1.323
docker image inspect "$img" >/dev/null 2>&1 || docker build -q -t "$img" "$here" >/dev/null
home=/home/node; opts=(--user root)
if [ "${AS:-}" = root ]; then
  home=/root
  if [ -n "${PRIV:-}" ]; then opts+=(--privileged)
  else opts+=(--cap-add SYS_ADMIN --cap-add NET_ADMIN --security-opt seccomp=unconfined --security-opt apparmor=unconfined); fi
fi
[ -n "${POLICY:-}" ] && opts+=(-v "$(cd "$POLICY" && pwd):/policy:ro")
[ -n "${PROJECT:-}" ] && opts+=(-v "$(cd "$PROJECT" && pwd):/project:ro")
[ -t 0 ] || opts+=(-i)   # pass stdin through when something is piped in (7.1)
[ -n "${ANTHROPIC_API_KEY:-}" ] && opts+=(-e ANTHROPIC_API_KEY)
[ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f "$HOME/.claude/.credentials.json" ] &&
  opts+=(-v "$HOME/.claude/.credentials.json:$home/.claude/.credentials.json:ro")
# Fake values the lessons look for. None of them match a real provider's token format.
opts+=(-e FAKE_DEPLOY_TOKEN=fake-env-value-456 -e GITHUB_TOKEN=fake-gh-value-789 -e APP_NOTE=plain-value-000)
docker run --rm "${opts[@]}" -e AS="${AS:-}" -e H="$home" "$img" bash -c '
  set -e
  mkdir -p /etc/claude-code
  if [ -d /policy ]; then
    for p in managed-settings.json managed-settings.d managed-mcp.json hooks; do
      [ -e "/policy/$p" ] && cp -r "/policy/$p" /etc/claude-code/
    done
    chown -R root:root /etc/claude-code; chmod -R go-w /etc/claude-code
  fi
  mkdir -p "$H/.claude" "$H/proj"; [ -d /project ] && cp -r /project/. "$H/proj/"
  if [ "$AS" = root ]; then cd "$H/proj"; exec "$@"; fi
  chown node:node "$H/.claude" "$H/proj"; chown -R node:node "$H/proj"
  cd "$H/proj"; exec runuser -u node -- env HOME="$H" "$@"
' _ "$@"
