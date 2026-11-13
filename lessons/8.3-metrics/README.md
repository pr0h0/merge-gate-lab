# 8.3 Metrics that mean something

`metrics.sh` writes `metrics-out/metrics.md` from real data on the fleet:

- gate outcome per PR (last commit's `security / gate`), fail rate, merged over a failed gate,
  exceptions in force (8.1 register)
- median PR time to merge (people vs Dependabot) and the gate's own run time
- Dependabot alert time to fix (`created_at` -> `fixed_at`) and open high/critical alerts per `tier`
- ruleset bypasses per month and how many have a written reason (8.1 `bypasses.sh`)
- coverage: % of repos passing each `check-coverage.sh` check (8.2)

Needs `gh`, `jq`, yq. About 2 minutes for the lab fleet plus 3 for bypasses.

```bash
cd lessons
ORG=<your-test-org> 8.3-metrics/metrics.sh
ORG=<your-test-org> BYPASSES=8.1-exceptions-bypasses/bypasses.json 8.3-metrics/metrics.sh   # reuse a saved bypass list
```

Limits: only the last commit of each PR is read, so a PR that failed, got fixed and then passed
counts as a pass. The bypass API keeps one month; keep each month's `bypasses.json`.
