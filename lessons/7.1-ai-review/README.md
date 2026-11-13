# 7.1 AI review in CI without giving it the keys

Files:

- `ai-review-cli.yml`: advisory review with plain `claude -p` (Claude Code 2.1.323 from npm). Two jobs:
  `review` (`contents: read`, holds the model key, model tools limited to Read/Grep/Glob) writes
  `review.md` to the job summary and an artifact; `post` (`pull-requests: write`, no key, no checkout)
  comments it on the PR.
- `ai-review-action.yml`: the same shape with `anthropics/claude-code-action` v1.0.275 (SHA-pinned).
- `ai-review/`: `prompt.md`, `schema.json` (structured verdict), `render.jq` (JSON -> comment).
  Copy to `.github/ai-review/` in the repo. Both workflows read these from the **base** commit,
  so a PR can't rewrite the instructions for its own review (it can still edit the workflow, see below).
- `review.sh <diff> <project>`: the same review locally in the 6.1 container, for testing prompts.
- `demo-pr.diff` + `demo-pr/`: a PR that adds `GET /diag/ping` with request data in `exec`.

## What protects what

| Risk | Control here | Not covered |
|---|---|---|
| Model runs PR code or a shell | `--tools Read,Grep,Glob` (CLI) / `--allowedTools` + `--disallowedTools` + `--permission-mode default` (action) | Read can still read any file in the checkout |
| Model output used as shell input | output passed through `env:` and `--body-file`, never `${{ }}` in `run:` | |
| Review approves or merges | no `pull-requests: write` in the job with the key; org setting: Actions can't approve PRs; check is not required | a person can still click merge |
| Key stolen by a PR | fork PRs get no secrets, so the review skips (notice) | anyone who can push a branch can edit the workflow on `pull_request` and read the key. Use a key with a spend limit in its own workspace, or workload identity federation (no stored key) |
| Runaway cost | `--max-turns 8`, `--max-budget-usd 0.50` (CLI), `timeout-minutes`, `concurrency` per workflow and PR | |

## Run it

```bash
cd lessons
# lint (no model)
docker run --rm -v "$PWD/7.1-ai-review:/w" -w /w rhysd/actionlint:1.7.12 ai-review-cli.yml ai-review-action.yml
docker run --rm -v "$PWD/7.1-ai-review:/w" -w /w ghcr.io/zizmorcore/zizmor:1.32.0 ai-review-cli.yml ai-review-action.yml

# the review, locally (model access as in 6.1; costs well under $0.01)
7.1-ai-review/review.sh 7.1-ai-review/demo-pr.diff 7.1-ai-review/demo-pr
```

Expected: actionlint exit 0; zizmor `0 high` (one low `adhoc-packages` for the npm install in the CLI
variant). The review returns `"verdict": "issues-found"` with a high command-injection finding on
`src/server.js`.

## Install in a repo

1. Merge `.github/ai-review/` first (the workflows read it from the base branch; without it they skip
   with a notice).
2. Add `ai-review-cli.yml` (or the action variant) as `.github/workflows/ai-review.yml`.
3. Add the `ANTHROPIC_API_KEY` repo secret. The lab org never got one: without it the review job
   prints `No ANTHROPIC_API_KEY in this run ... AI review skipped.` and `post` is skipped.
4. Don't add `ai-review` to required status checks.

`anthropics/claude-code-action` and the `oven-sh/setup-bun` action it calls were allowed under the
lab org's `allowed_actions: selected` + `verified_allowed: true` policy without an extra pattern.
