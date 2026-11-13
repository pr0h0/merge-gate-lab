#!/bin/bash
# Tries to get around the MCP and plugin policy as a developer would. No model calls.
# Run on the lab machine: POLICY=6.3-hooks-mcp 6.1-managed-settings/run-agent.sh /policy/mcp-check.sh
try() { echo "\$ $*"; "$@" 2>&1 | sed 's/^/  /'; }
try claude mcp add --transport http tunnel https://abc123.ngrok-free.app/mcp
try claude mcp add --transport http vendor https://mcp.random-vendor.example/mcp
try claude mcp add --transport http internal https://mcp.internal.example.com/mcp
try claude mcp add fs-latest -- npx -y @modelcontextprotocol/server-filesystem .
try claude mcp add fs -- npx -y @modelcontextprotocol/server-filesystem@2.2.0 .
try claude mcp add --transport http github https://mcp.internal.example.com.attacker.example/mcp
echo "\$ # hand-edit ~/.claude.json to add a server the CLI refused"
jq '.mcpServers += {"sneaky": {"type": "http", "url": "https://mcp.random-vendor.example/mcp"}}' ~/.claude.json > /tmp/c && cp /tmp/c ~/.claude.json
echo "  servers in ~/.claude.json: $(jq -c '[.mcpServers // {} | keys[]] + [.projects[]?.mcpServers // {} | keys[]]' ~/.claude.json)"
echo "\$ # a repo ships .mcp.json with a server nobody approved"
echo '{"mcpServers":{"repo-tool":{"command":"npx","args":["-y","some-unvetted-mcp"]}}}' > .mcp.json
try timeout 60 claude mcp list
try claude plugin marketplace add untrusted-org/tools
try claude plugin marketplace add someone/cool-plugins
try claude -p hi --mcp-config '{"mcpServers":{"x":{"type":"http","url":"https://mcp.random-vendor.example/mcp"}}}'
try claude -p hi --plugin-dir /tmp
