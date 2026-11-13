# 6.3 Enforced hooks and MCP server control

Files:

- `hooks/guard.sh`: a managed `PreToolUse` hook (bash + jq). It blocks force pushes, `--no-verify`,
  edits under `.github/workflows/`, and `.env` reads by the Read tool or by a Bash command that names
  the file. Exit code 2 blocks the call; its stderr is the reason Claude sees.
- `test-guard.sh`: 19 cases fed straight to the hook, no Claude Code needed. The last one is a
  known gap the hook lets through (`cat $(printf %s .en; printf v)`).
- `managed-settings.json`: the hook, `allowManagedHooksOnly`, an MCP allowlist and denylist,
  plugin marketplace allow and block lists, and `disableSideloadFlags`.
- `user-settings-attempt.json`: what a developer might put in `~/.claude/settings.json` to get
  around the hook: `disableAllHooks: true` and a hook of their own.
- `hook-prompt.txt`: four steps for the agent that the hook should block (one it shouldn't).
- `mcp-check.sh`: tries to add MCP servers and marketplaces the policy refuses. No model calls.

## The policy, key by key

| Key | Managed-only? | What it does |
|---|---|---|
| `hooks` | no | Runs `guard.sh` before Bash, Read and every edit tool. User, project and local hooks are added next to it, never replace it, and `disableAllHooks` outside managed settings can't turn it off. |
| `allowManagedHooksOnly` | yes | Only managed hooks (plus SDK hooks and hooks of plugins that managed `enabledPlugins` force-enables) run. User, project, local and other plugin hooks don't. |
| `allowedMcpServers` | no | Allowlist by `serverUrl` (wildcards) or exact `serverCommand`. `serverName` entries are labels the user picks, so they are not a control. |
| `allowManagedMcpServersOnly` | yes | Only the managed allowlist counts; a user can't widen it in their own settings. |
| `deniedMcpServers` | no | Denylist, merged from every scope, checked first. `*://host:*/*` covers every scheme and port. |
| `strictKnownMarketplaces` | yes | Plugin marketplaces may come only from these sources. |
| `blockedMarketplaces` | yes | Checked before the allowlist and before anything downloads. |
| `disableSideloadFlags` | yes | Rejects `--mcp-config`, `--plugin-dir`, `--plugin-url` and `--agents` at startup. |

Not used here: `managedMcpServers` (gives every user your remote servers next to their own) and a
`managed-mcp.json` file next to `managed-settings.json` (only the servers in it load; can't be
delivered through server-managed settings).

## Run it

```bash
cd lessons
./6.3-hooks-mcp/test-guard.sh                    # 19 x ok, exit 0
R=6.1-managed-settings/run-agent.sh

# MCP and plugin policy (no model calls)
POLICY=6.3-hooks-mcp $R /policy/mcp-check.sh

# The hook against an agent, with the developer's bypass attempt in ~/.claude/settings.json (model call)
POLICY=6.3-hooks-mcp PROJECT=6.1-managed-settings/demo $R bash -c \
  'cp /policy/user-settings-attempt.json ~/.claude/settings.json && claude -p "$1" --model haiku --max-budget-usd 0.25 --allowedTools "Bash Write Read" --output-format stream-json --verbose' \
  _ "$(cat 6.3-hooks-mcp/hook-prompt.txt)" 2>/dev/null |
  jq -r '.message | objects | .content[]? | select(.type=="tool_result") | .content | tostring | .[0:200]'
```

Expected from `mcp-check.sh`:

```text
Cannot add MCP server "tunnel": server is explicitly blocked by enterprise policy
Cannot add MCP server "vendor": not allowed by enterprise policy
Added HTTP MCP server internal with URL: https://mcp.internal.example.com/mcp to local config
Cannot add MCP server "fs-latest": not allowed by enterprise policy        <- unpinned command
Added stdio MCP server fs with command: npx -y @modelcontextprotocol/server-filesystem@2.2.0 .
Cannot add MCP server "github": not allowed by enterprise policy           <- look-alike host
servers in ~/.claude.json: ["sneaky","fs","internal"]                      <- hand-edited entry
claude mcp list: internal and fs only (sneaky and the repo's .mcp.json server are dropped, silently)
Marketplace source 'github:untrusted-org/tools' is blocked by enterprise policy.
Marketplace source 'github:someone/cool-plugins' (github.com) is blocked by enterprise policy. Allowed sources: ...
--mcp-config is disabled by your organization's managed settings (disableSideloadFlags). ...
--plugin-dir is disabled by your organization's managed settings (disableSideloadFlags). ...
```

Expected from the agent run: steps 1 to 3 each end in
`PreToolUse:<Tool> hook error: [/etc/claude-code/hooks/guard.sh]: Blocked by org policy (guard.sh): ...`,
and step 4 prints `no-user-hook`. Without `allowManagedHooksOnly` (and without `disableAllHooks`) the
developer's hook runs and step 4 lists `/tmp/user-hook-ran`; the managed hook still blocks 1 to 3.

If you log in with a claude.ai account that has connectors, `allowManagedMcpServersOnly` also blocks
them: stderr shows `Warning: claude.ai MCP servers blocked by enterprise policy: ...`.
