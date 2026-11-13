# 1.2 Scanning every repo: settings, workflows and secrets in history

`fleet-scan.sh` mirror-clones every non-archived repo in `$ORG` and runs, in docker:

- gitleaks v8.30.1 over the full history of every ref (`--redact`, so values stay out of the report)
- a plain `git log --all` check for files that should never be committed (`.env`, keys, `.pem`)
- zizmor 1.32.0 `--offline` over the default branch's workflows
- Semgrep 1.185.0 with `p/default` (or `SEMGREP_CONFIG=...`) over the default branch

```bash
ORG=<your-test-org>
cd lessons/1.2-fleet-scan
ORG=$ORG ./fleet-scan.sh            # writes ./scan/ (gitignored)
```

Output: a table of counts per repo, `scan/summary.json`, and raw outputs in `scan/raw/`.
Needs `gh`, `git`, `jq` and docker. Semgrep downloads `p/default` from the registry.
zizmor online audits: pass a token into the container (`-e GH_TOKEN`), see the lesson.

Treat `scan/` as sensitive: the mirrors contain the secrets, even though the reports are redacted.
