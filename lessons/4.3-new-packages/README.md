# 4.3 Catching invented and too-new packages before merge

- `gate/`: security-workflows v2.2.0. New check `packages` (PRs only):
  `scripts/new-packages.js` finds every npm package the PR adds (new names in any
  `package.json`, new `name@version` entries in `package-lock.json` / `npm-shrinkwrap.json`)
  and reads each one's full document from the registry (`GET https://registry.npmjs.org/<name>`).
  - `package-not-found` (404), `package-too-new` (created < `MIN_PACKAGE_AGE_DAYS`, default 30),
    `version-not-found`, `version-too-new` (published < `MIN_VERSION_AGE_DAYS`, default 7): findings.
  - Direct dependency with no `repository` field, or one maintainer: a warning annotation only.
  - Any other registry error fails the gate (fail closed).
  - `scripts/new-packages.test.js`: self-test without network, run by the `unit` job in `self-test.yml`.

```bash
ORG=<your-test-org>
cd lessons
node --test 4.3-new-packages/gate/scripts/*.test.js

ORG=$ORG 3.1-reusable-gate/publish-gate.sh 4.3-new-packages/gate "Security gate v2.2.0: new npm packages must exist and must not be brand new"
# wait for `security / gate` and `unit`, merge, tag v2.2.0, then
ORG=$ORG 3.1-reusable-gate/rollout-callers.sh v2.2.0 block
ORG=$ORG 4.1-dependabot/merge-fleet-prs.sh security-gate
```

Demo PRs on a fleet repo: add a name that doesn't exist to `package.json` (fails twice:
`lockfile-not-updated` and `package-not-found`); `npm install ms@2.1.3` (passes); and
`npm install <package>@<version published this week> --min-release-age=0` (fails `version-too-new`).
