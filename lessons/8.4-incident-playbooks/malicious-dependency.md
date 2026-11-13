# Playbook: a dependency turned out to be malicious

Use this when an advisory, a Dependabot malware alert, a registry takedown or a news post says
that a package version you might use steals credentials or runs code on install. Copy it into
the incident ticket. `ORG`, `PKG` and `VER` are shell variables.

## 1. Where is it? (first 30 minutes)
1. Get the facts from the advisory: package name, ecosystem, bad versions, when they were
   published, what the payload does (install script? runtime code? which hosts it calls).
2. Find every repo that has it, at which version, direct or transitive:
   `ORG=$ORG ./find-package.sh "$PKG"` (all versions) or `./find-package.sh "$PKG" "$VER"`.
   The script reads each repo's dependency graph SBOM, so it sees the default branch only.
   Open PRs and other branches: search them with `gh pr list -R $ORG/<repo> --state open`
   and `git grep "$PKG" $(git for-each-ref --format='%(refname)' refs/remotes)` in a clone.
3. Check what else installs packages outside the lockfile: Dockerfiles (`npm install -g`),
   `npx <pkg>` in workflows, developer machines and agent sandboxes.

## 2. Did anything run it?
1. Install-time payload: the `INSTALL-SCRIPT` column says whether the lockfile marks the
   package `hasInstallScript`. With `ignore-scripts=true` in `.npmrc` (lesson 4.2) npm skips
   those scripts in CI. Without it, assume every CI run and every laptop that installed the bad
   version ran the payload.
2. When did the bad version arrive? `git log -p -S "\"$PKG\"" -- package-lock.json` in a clone
   shows the commit that added or bumped it. Exposure window = that commit until the fix.
3. Which CI runs installed it in that window? `gh run list -R $ORG/<repo> --created ">=<date>"`
   (every run of a workflow that runs `npm ci`). Runtime payload: did a deploy ship it?
4. What could those jobs reach? The job's `GITHUB_TOKEN` (5.1: read-only by default here, gone
   when the job ends), every secret the workflow references, environment secrets after approval,
   cloud roles via OIDC, the runner's network. List them per workflow and treat them as leaked.

## 3. Contain
1. Rotate every secret from step 2.4 (follow the leaked-secret playbook for each one).
2. Pin away from the bad version in a normal PR per repo, with the lockfile:
   a direct dependency: set a safe version in `package.json`; a transitive one: add an npm
   `overrides` entry, e.g. `"overrides": { "<pkg>": "<safe version>" }`, then
   `npm install --package-lock-only` and commit both files. The gate's lockfile check fails a
   `package.json` change without its lockfile.
3. Use `4.1-dependabot/fleet-pr.sh` for one PR per repo, and `merge-fleet-prs.sh` to merge
   them once the gate passes.
4. Keep it out: Dependabot `ignore` for the bad versions, and a gate exception is NOT the tool
   here (exceptions accept a finding; this one you want to keep failing).
5. If a developer or agent machine installed it with scripts on, treat the machine as
   compromised: rotate the person's tokens (GitHub, npm, cloud), reimage per your IT process.

## 4. Close
- Dependabot alerts for it: close as fixed by merging the bump, never dismiss to silence them.
- Record: repos affected, versions, did install scripts run, which secrets were rotated, time
  from advisory to last repo fixed (a metric for 8.3).
- Ask why it got in: was it a new package (4.3's registry check would flag a package under 30
  days or a version under 7 days), a minor bump inside a `^` range, an agent's suggestion?

## Notes
- Dependabot malware alerts exist for npm and other ecosystems and need Dependabot alerts on
  the repo, but they are switched on separately (repo settings or a custom security
  configuration in the UI).
- An SBOM reflects the last dependency graph snapshot of the default branch. A brand-new push
  can take a minute to show up.
