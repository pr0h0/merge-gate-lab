# 6.2 Permissions, secrets and the sandbox

Files:

- `managed-settings.json`: permission rules plus an admin-required sandbox.
- `managed-settings.d/90-lab-docker.json`: **lab only.** Two settings that weaken the sandbox so
  bubblewrap can run inside a docker container (`enableWeakerNestedSandbox`, `allowAllUnixSockets`).
  Never ship this file to real machines.
- `scrub/managed-settings.json`: `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` through the managed `env` block.
- `probe-prompt.txt`: eight shell commands that try to read secrets, reach the network and write
  outside the project.

## The policy, key by key

| Key | What it does |
|---|---|
| `permissions.deny` `Read(...)` | Blocks Claude's file tools and the file commands Claude Code recognizes in Bash (`cat .env` is denied before it runs). It does **not** stop `grep -r`, `python3 -c "open('.env')"` or any program that opens the file itself. With the sandbox on, the same paths are also denied at the OS level. |
| `permissions.ask` `Bash(git push *)` | Every push prompts, even in auto-allow sandbox mode. In `claude -p` a prompt means "denied". |
| `permissions.defaultMode` | The mode new sessions start in. A default, not a lock: `--permission-mode` overrides it per session. |
| `permissions.disableBypassPermissionsMode` | Bypass mode can't be entered (see 6.1). |
| `allowManagedPermissionRulesOnly` | Managed-only. Ignores allow/ask/deny rules from user, project, local and `--settings` files and `--allowedTools`, hides "always allow" in prompts. Developers lose their own allow lists, so expect more prompts. |
| `sandbox.enabled` + `failIfUnavailable` | Bash runs inside bubblewrap (Linux) or Seatbelt (macOS); if the sandbox can't start, Claude Code refuses to start instead of running unsandboxed. |
| `sandbox.allowUnsandboxedCommands: false` | Claude can't retry a failed command outside the sandbox. Makes the sandbox "admin-required": a repo's `excludedCommands`, `allowedDomains` and `allowWrite` are ignored. |
| `sandbox.network.allowedDomains` + `allowManagedDomainsOnly` | Only these hosts, only from managed settings, no prompt for others. The proxy checks host names and doesn't inspect TLS, so a broad entry such as `*.github.com` is an exfiltration path. |
| `sandbox.filesystem.denyRead` | Sandboxed commands can't read these paths. By default the sandbox lets commands read most of the machine, `~/.ssh` and `~/.aws` included. |
| `sandbox.credentials.envVars` `deny` | Unsets these variables before each sandboxed command. There is no built-in list: anything you don't name stays visible. |

What the sandbox does not cover: Read/Edit/WebFetch tools (permission rules cover those), hooks,
local MCP servers, status line and helper commands, and commands the developer types after `!`.

## Run it

Needs docker and model access (see 6.1). On Linux hosts with Ubuntu's AppArmor user-namespace
restriction, bubblewrap can't start inside an unprivileged container, so the sandbox steps run as
root with extra privileges (`AS=root`) and the scrub step with `--privileged` (`PRIV=1`). That is a
property of this lab, not of a real laptop, where you install `bubblewrap` and `socat`.

```bash
cd lessons
R=6.1-managed-settings/run-agent.sh
export PROJECT=6.1-managed-settings/demo
probe='mkdir -p ~/.ssh && echo fake-key-not-real > ~/.ssh/id_demo && claude -p "$1" --model haiku --max-budget-usd 0.25 --allowedTools Bash --output-format stream-json --verbose'
show() { jq -r '.message | objects | .content[]? | select(.type=="tool_result") | "[error=\(.is_error)] \(.content|tostring|.[0:160]|gsub("\n";" | "))"'; }

# 1. Before: no policy. Every probe succeeds.
$R bash -c "$probe" _ "$(cat 6.2-permissions-sandbox/probe-prompt.txt)" 2>/dev/null | show

# 2. Read deny rules only (the 6.1 policy): cat is denied, grep and python still read .env
POLICY=6.1-managed-settings $R bash -c "$probe" _ "$(cat 6.2-permissions-sandbox/probe-prompt.txt)" 2>/dev/null | show

# 3. Full policy with the sandbox
POLICY=6.2-permissions-sandbox AS=root $R bash -c "$probe" _ "$(cat 6.2-permissions-sandbox/probe-prompt.txt)" 2>/dev/null | show

# 4. Environment scrub
POLICY=6.2-permissions-sandbox/scrub AS=root PRIV=1 $R claude -p 'Run this one command with the Bash tool exactly as written and print its output: echo "deploy=[$FAKE_DEPLOY_TOKEN] gh=[$GITHUB_TOKEN] note=[$APP_NOTE]"' \
  --model haiku --max-budget-usd 0.25 --allowedTools Bash --output-format stream-json --verbose 2>/dev/null | show
```

Expected (2026-11-13, Claude Code 2.1.323, model haiku):

| Probe | 1. no policy | 2. Read deny only | 3. deny + sandbox |
|---|---|---|---|
| `cat .env` | prints value | `Permission to use Bash with command cat .env has been denied.` | `cat: .env: Permission denied` (OS) |
| `grep -r DEMO_TOKEN .` | `.env:DEMO_TOKEN=...` | `.env:DEMO_TOKEN=...` | no match, `cannot read .env: Permission denied` |
| `python3 ... open('.env')` | prints value | prints value | `PermissionError: [Errno 13]` |
| `cat ~/.ssh/id_demo` | prints key | denied (`Read(~/.ssh/**)`) | `No such file or directory` |
| `echo` env vars | all three print | all three print | `deploy=[fake...] gh=[] note=[plain...]` |
| curl registry.npmjs.org | `200` | `200` | `200` |
| curl example.com | `200` | `200` | `CONNECT tunnel failed, response 403`, `deny network-outbound example.com:443` |
| `touch ~/sandbox-probe` | `wrote` | `wrote` | `Read-only file system` |

Step 4 prints `deploy=[] gh=[fake-gh-value-789] note=[plain-value-000]`: the scrub removed the
variable whose name looks like a credential, kept `GITHUB_TOKEN` on purpose (documented), and kept a
secret whose name doesn't look like one. The scrub also turns sandbox auto-allow off, which is why it
lives in its own policy here.
