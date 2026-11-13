# Throwaway machine for module 6. Claude Code is pinned; the policy is copied in at start by run-agent.sh.
FROM node:22-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends bubblewrap socat jq git ca-certificates curl python3 \
 && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code@2.1.323
