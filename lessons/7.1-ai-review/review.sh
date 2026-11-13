#!/bin/bash
# Run the CI review locally: the same prompt, schema and tool list as ai-review-cli.yml, in the
# throwaway container from 6.1 (needs model access, see 6.1 README). Prints the review JSON
# plus cost and turns. Exit 0 whatever the verdict: the review is advisory.
#   ./review.sh <pr.diff> <project-dir-after-the-change> [prompt.md]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
diff=${1:?diff file}; proj=${2:?project dir}; prompt=${3:-$here/ai-review/prompt.md}
PROJECT="$proj" "$here/../6.1-managed-settings/run-agent.sh" claude -p "$(cat "$prompt")" \
  --model haiku --max-budget-usd 0.25 --max-turns 8 \
  --tools Read,Grep,Glob --permission-mode default \
  --output-format json --json-schema "$(cat "$here/ai-review/schema.json")" < "$diff" |
  jq '{review: .structured_output, cost_usd: .total_cost_usd, turns: .num_turns, subtype}'
