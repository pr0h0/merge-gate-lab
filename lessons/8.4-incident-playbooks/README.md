# 8.4 Incident playbooks: leaked secret, malicious dependency

- `leaked-secret.md`: contain (revoke first), scope, optional history cleanup, close the alert, prevent.
- `malicious-dependency.md`: find it, did it run, contain (rotate, pin, override), close, prevent.
- `find-package.sh`: which repos have an npm package, which version, direct or transitive,
  whether the lockfile marks it `hasInstallScript`, and the repo's `ignore-scripts` setting.
  Reads `GET /repos/{o}/{r}/dependency-graph/sbom` (default branch). Exit 1 if found, 0 if not,
  2 if an SBOM couldn't be read.

## Tabletop

```bash
cd lessons/8.4-incident-playbooks
ORG=<your-test-org> ./find-package.sh lodash
ORG=<your-test-org> ./find-package.sh express 4.22.3
ORG=<your-test-org> ./find-package.sh debug          # a transitive one
ORG=<your-test-org> ./find-package.sh lodash 4.17.20 # the version you had before module 4
```

Then walk through `malicious-dependency.md` as if `express 4.22.3` had just been reported
malicious: which repos, did CI run its scripts, which secrets did those jobs see, what PR fixes it.
