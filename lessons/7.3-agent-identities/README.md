# 7.3 Coding agents and autofix bots: scope, network and approval

Files:

- `check-agent-guardrails.sh`: checks that Actions can't approve PRs, the default token is read-only,
  no GitHub App or deploy key is on any repo's `baseline` ruleset bypass list, code owner review is on,
  CODEOWNERS covers `.github/`, and lists every installed GitHub App (WARN for `workflows: write`,
  `administration: write` or installed on all repos). Needs an org owner token.
- `app-manifest.json`: a GitHub App for the org's coding agent: contents + pull requests write,
  issues + checks read, no workflows, no administration, no webhook, private.

## Run it

```bash
cd lessons
ORG=<your-test-org> 7.3-agent-identities/check-agent-guardrails.sh; echo "exit $?"
```

Expected on the lab fleet after module 6: 20 PASS lines, `INFO no GitHub Apps installed`, exit 0.

## Register the agent's GitHub App (UNTESTED in the lab)

The manifest flow needs a browser: GitHub only accepts the manifest as a form POST to
`https://github.com/organizations/<org>/settings/apps/new`, the owner confirms in the UI, GitHub
redirects to `redirect_url` with a `code`, and `POST /app-manifests/{code}/conversions` returns the
App id and private key (within one hour). For one App it is simpler to do it by hand:

1. Org **Settings > Developer settings > GitHub Apps > New GitHub App**. Name it, untick **Webhook Active**.
2. Repository permissions exactly as in `app-manifest.json`: Contents read/write, Pull requests
   read/write, Issues read, Checks read, Metadata read. Leave **Workflows** and **Administration** at No access.
3. **Only on this account**. Create, generate a private key, store it in your agent platform's secret store.
4. **Install App > Only select repositories** (the repos the agent works on, not all).
5. Rerun `check-agent-guardrails.sh`: the App shows as `INFO app ... repos=selected workflows=none`.

## Simulated agent PR (what we ran)

A PR from branch `agent/fix-ci-node` that changes `node-version` in `.github/workflows/ci.yml`:
checks pass, review requested from the security team, `mergeStateStatus: BLOCKED`, the author's
`gh pr review --approve` -> `Can not approve your own pull request`, `gh pr merge --squash` ->
`the base branch policy prohibits the merge`. Closed unmerged.
