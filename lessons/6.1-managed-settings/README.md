# 6.1 Managed settings: what an org can enforce on Claude Code

Files:

- `managed-settings.json`: a starter org policy. JSON has no comments, so each key is explained below.
- `check-managed.sh <expected.json>`: run on a developer machine (Linux or macOS). It checks that the
  managed file exists, is owned by root, is not group/world writable, parses, and matches the file
  the org shipped. Exit 1 on any FAIL. Run it from your device management tool and alert on FAIL.
- `Dockerfile` + `run-agent.sh`: a throwaway "developer machine" with Claude Code 2.1.323. The
  policy is copied to `/etc/claude-code/` as root; Claude Code runs as the unprivileged user `node`.
  Modules 6.2 to 6.4 use the same runner.
- `demo/`: a tiny project with fake `.env` files and a `.claude/settings.json` that tries to allow
  reading them.

## The starter policy, key by key

| Key | Managed-only? | What it does here |
|---|---|---|
| `permissions.deny` | no (any scope) | Blocks Claude's file tools, and the file commands Claude Code recognizes in Bash (`cat`, `head`, `sed`, redirects), from `.env*` files, `secrets/` and credential files in the home directory. `**/` makes the rule match at any depth. A deny at any level beats an allow at every level. |
| `permissions.disableBypassPermissionsMode` | no (any scope) | `"disable"`: `--dangerously-skip-permissions` and `--permission-mode bypassPermissions` stop working. In our test the session started in `default` mode instead, with no error. In managed settings nobody below can undo it. |
| `deniedMcpServers` | no (any scope) | Blocks MCP servers behind a tunnel domain on every port and scheme. Denylists merge from every scope, so users can add entries but not remove yours. |
| `cleanupPeriodDays` | no | Local transcripts kept 30 days. An example of a plain default, not a security lock. |

Keys only a managed source can set (in a user or project file they do nothing):
`allowManagedPermissionRulesOnly`, `allowManagedHooksOnly`, `allowManagedMcpServersOnly`,
`managedMcpServers`, `strictKnownMarketplaces`, `blockedMarketplaces`, `strictPluginOnlyCustomization`,
`disableSideloadFlags`, `disableCommandPluginSources`, `sandbox.network.allowManagedDomainsOnly`,
`sandbox.filesystem.allowManagedReadPathsOnly`, `sandbox.bwrapPath`, `forceRemoteSettingsRefresh`,
`managedSourcesBehavior`, `parentSettingsBehavior`, `policyHelper`, `claudeMd`, `channelsEnabled`,
`allowedChannelPlugins`, `pluginTrustMessage`, `pluginSuggestionMarketplaces`, `allowAllClaudeAiMcps`,
`wslInheritsWindowsSettings`. Lessons 6.2 and 6.3 use several of them.

## Where the file goes

| OS | File policy | MDM / OS policy |
|---|---|---|
| Linux, WSL | `/etc/claude-code/managed-settings.json` (+ `managed-settings.d/*.json`) | none |
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` | configuration profile, domain `com.anthropic.claudecode` |
| Windows | `C:\Program Files\ClaudeCode\managed-settings.json` | `HKLM\SOFTWARE\Policies\ClaudeCode`, value `Settings` (JSON string) |

`HKCU\SOFTWARE\Policies\ClaudeCode` also works, but any user can write it, so it is not an admin source.
Server-managed settings (claude.ai admin console) need Claude for Teams or Enterprise.

## Run it

You need docker. Steps 1 to 3 make no model calls. Step 4 needs model access: export
`ANTHROPIC_API_KEY`, or on Linux keep your `~/.claude/.credentials.json` (mounted read-only).
Each model step is capped with `--max-budget-usd 0.25`; ours cost under $0.01.

```bash
cd lessons
R=6.1-managed-settings/run-agent.sh
export POLICY=6.1-managed-settings PROJECT=6.1-managed-settings/demo

# 1. The policy is in place and the developer can't change it
$R bash -c 'ls -l /etc/claude-code; /policy/check-managed.sh /policy/managed-settings.json'
$R bash -c 'echo "{}" > /etc/claude-code/managed-settings.json'      # Permission denied

# 2. A local admin can, and the check notices
AS=root $R bash -c 'jq "del(.permissions.deny)" /etc/claude-code/managed-settings.json > /tmp/m &&
  cp /tmp/m /etc/claude-code/managed-settings.json && /policy/check-managed.sh /policy/managed-settings.json'

# 3. A broken policy file stops Claude Code from starting
mkdir -p /tmp/bad && echo '{ "permissions": ' > /tmp/bad/managed-settings.json
POLICY=/tmp/bad $R claude -p hi

# 4. Project settings, --settings, --allowedTools and the bypass flag all try to allow the read
$R claude -p 'Use the Read tool to read ./.env and then ./config/.env.local and print what each contains. If a read is denied, print the exact error. Do not try any other method.' \
  --model haiku --max-budget-usd 0.25 --allowedTools Read \
  --settings '{"permissions":{"allow":["Read(**/.env)","Read(**/.env.*)"]}}' \
  --dangerously-skip-permissions --output-format stream-json --verbose |
  jq -c 'if .type=="system" and .subtype=="init" then {permissionMode}
         else (.message.content[]? | select(.type=="tool_result") | {is_error, content}) end'
# Then the same command with `unset POLICY` first: both files print, mode bypassPermissions.
```

Expected: step 1 all PASS, then `Permission denied`; step 2 `FAIL content differs` and the missing
deny list; step 3 `Managed settings document could not be parsed as a JSON object`; step 4
`"permissionMode":"default"` and two `File is in a directory that is denied by your permission settings.`
