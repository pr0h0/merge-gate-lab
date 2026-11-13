# 3.3 Secrets, dependencies and workflow lint in the same gate

- `gate/`: security-workflows v1.2.0. `scripts/gate.sh` now runs four checks and writes one
  summary table with a count per tool:
  - Semgrep (from 3.2).
  - gitleaks v8.30.1 (digest-pinned image) over every commit in the PR (`base..head`), with
    `rules/gitleaks.toml`: the default rules plus `internal-api-token` for the org's own token format.
  - Dependency review: `GET /repos/{owner}/{repo}/dependency-graph/compare/{base}...{head}`, the API
    behind `actions/dependency-review-action`; fails on added packages with a high or critical advisory.
    Needs the dependency graph on the repo.
  - actionlint 1.7.12 on the PR's workflows minus what it already reports on the base.

```bash
ORG=<your-test-org>
cd lessons

# Dependency review needs the dependency graph: turn it on in the 2.4 configuration
id=$(gh api "orgs/$ORG/code-security/configurations" --jq '.[] | select(.name=="secret-protection") | .id')
gh api -X PATCH "orgs/$ORG/code-security/configurations/$id" -f dependency_graph=enabled --jq .dependency_graph
gh api "repos/$ORG/payments-api/dependency-graph/sbom" --jq '.sbom.packages | length'

# Release v1.2.0 and bump the fleet (same steps as 3.2, new tag)
ORG=$ORG 3.1-reusable-gate/publish-gate.sh 3.3-gate-scanners/gate "Security gate v1.2.0: gitleaks, dependency review and actionlint"
```

Then open the three demo PRs from the lesson on `payments-api`: a test fixture with a fake
`INTERNAL_API_TOKEN` added in one commit and removed in the next, `minimist` 1.2.5 in
`package.json`, and a workflow that puts the PR title into `run:`. Each fails the gate. Close them.
