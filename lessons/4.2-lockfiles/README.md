# 4.2 Lockfiles and install scripts

- `npm-policy-demo.sh`: runs npm 11.21.2, npm 12.2.2 and pnpm 12.18.0 in `node:24-alpine`
  containers and shows what each does with a dependency's install script (`core-js`), with
  `allowScripts` / `allowBuilds`, with a release-age limit, and with a git dependency.
- `npmrc`: the `.npmrc` every fleet repo gets: `ignore-scripts=true`, `min-release-age=7`.
- `gate/`: security-workflows v2.1.0. New check `lockfile` in `scripts/gate.sh` (PRs only):
  - `lockfile-not-updated`: the dependency fields of a `package.json` changed, and no lockfile
    in the same directory (`package-lock.json`, `npm-shrinkwrap.json`, `yarn.lock`,
    `pnpm-lock.yaml`) changed.
  - `non-registry-source`: an npm lockfile entry the PR adds resolves from somewhere other than
    `ALLOWED_REGISTRY` (default `https://registry.npmjs.org/`): git, http tarball, `file:`.
    yarn and pnpm lockfiles are not parsed for this.

```bash
ORG=<your-test-org>
cd lessons
./4.2-lockfiles/npm-policy-demo.sh

# Lockfile, .npmrc and `npm ci` in CI, one PR per repo (needs npm 11.10+ for --min-release-age)
ORG=$ORG 4.1-dependabot/fleet-pr.sh lockfile "Commit a lockfile, install with npm ci, no install scripts" \
  "cp $PWD/4.2-lockfiles/npmrc .npmrc && npm install --package-lock-only --ignore-scripts --min-release-age=7 --no-audit --no-fund && sed -i 's/run: npm install\$/run: npm ci/' .github/workflows/ci.yml"
ORG=$ORG 4.1-dependabot/merge-fleet-prs.sh lockfile

# Gate v2.1.0: publish, wait, merge, tag, roll out (as in 3.1)
ORG=$ORG 3.1-reusable-gate/publish-gate.sh 4.2-lockfiles/gate "Security gate v2.1.0: lockfile must change with dependencies, no non-registry sources"
ORG=$ORG 3.1-reusable-gate/rollout-callers.sh v2.1.0 block
ORG=$ORG 4.1-dependabot/merge-fleet-prs.sh security-gate
```

On macOS, `sed -i` needs `sed -i ''`.
