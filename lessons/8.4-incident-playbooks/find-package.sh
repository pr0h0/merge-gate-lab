#!/usr/bin/env bash
# Lesson 8.4: which repos in the org have an npm package, at which version, direct or transitive,
# and could its install scripts have run in CI? Reads each repo's dependency graph SBOM
# (GET /repos/{o}/{r}/dependency-graph/sbom, the default branch only), the lockfile's
# hasInstallScript flag and the repo's .npmrc.
# Prints a table; exits 1 if any repo matches, 0 if none, 2 if a repo's SBOM couldn't be read.
#
#   ORG=<your-test-org> ./find-package.sh lodash              # any version
#   ORG=<your-test-org> ./find-package.sh express 4.22.3      # one version
#   ORG=<your-test-org> ./find-package.sh @scope/name '^1\.4\.' # versions matching a regex
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
PKG="${1:?usage: find-package.sh <npm-package> [version-regex]}"
VER="${2:-.*}"
purl="pkg:npm/${PKG/@/%40}@"   # purls encode the scope's @
found=0; unread=0

file() { gh api "repos/$ORG/$1/contents/$2" --jq .content 2>/dev/null | base64 -d 2>/dev/null || true; }

printf '%-20s %-12s %-10s %-15s %s\n' REPO VERSION DEPENDENCY INSTALL-SCRIPT NPMRC
while read -r r; do
  if ! sbom=$(gh api "repos/$ORG/$r/dependency-graph/sbom" 2>/dev/null); then
    printf '%-20s %s\n' "$r" "SBOM unreadable (dependency graph off?)"; unread=1; continue
  fi
  hits=$(jq -r --arg purl "$purl" --arg ver "^($VER)$" '
    .sbom as $s
    | ([$s.relationships[] | select(.relationshipType == "DESCRIBES") | .relatedSpdxElement]) as $roots
    | $s.packages[]
    | select(any(.externalRefs[]?; .referenceType == "purl" and (.referenceLocator | startswith($purl))))
    | select(.versionInfo | test($ver))
    | .SPDXID as $id
    | "\(.versionInfo) \(if any($s.relationships[]; .relatedSpdxElement == $id and (.spdxElementId | IN($roots[]))) then "direct" else "transitive" end)"' <<<"$sbom")
  [[ -z "$hits" ]] && continue
  found=1
  lock=$(file "$r" package-lock.json); [[ -n "$lock" ]] || lock='{"packages":{}}'
  npmrc=$(file "$r" .npmrc | grep -E '^\s*ignore-scripts\s*=' | tr -d ' ' || true)
  while read -r v dep; do
    # hasInstallScript is set on lockfile entries whose package has preinstall/install/postinstall.
    inst=$(jq -r --arg p "node_modules/$PKG" --arg v "$v" \
      '[(.packages // {}) | to_entries[] | select((.key == $p or (.key | endswith("/" + $p))) and .value.version == $v) | .value.hasInstallScript // false] | if length == 0 then "no lockfile" elif any then "YES" else "no" end' \
      <<<"$lock" 2>/dev/null || echo "?")
    printf '%-20s %-12s %-10s %-15s %s\n' "$r" "$v" "$dep" "$inst" "${npmrc:-no ignore-scripts}"
  done <<<"$hits"
done < <(gh api --paginate "orgs/$ORG/repos?per_page=100" --jq '.[] | select(.archived | not) | .name')

[[ $unread == 1 ]] && exit 2
[[ $found == 1 ]] && exit 1 || exit 0
