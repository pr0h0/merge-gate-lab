#!/usr/bin/env bash
# Show what npm 11, npm 12 and pnpm 12 do with dependency install scripts, release age and
# git dependencies, in throwaway containers (needs docker; nothing is installed on your machine).
# core-js is a real package with a postinstall script; npm logs "core-js@3.51.0 postinstall" when it runs.
#
#   ./npm-policy-demo.sh
set -euo pipefail
IMAGE="node:24-alpine"
# The cases are run by sh inside the container, so their $ expand there.
# shellcheck disable=SC2016
npm_case='
set -u
npm i -g -s "npm@$V" >/dev/null 2>&1; echo "=== npm $(npm -v)"
cd "$(mktemp -d)"
echo "{\"name\":\"a\",\"version\":\"1.0.0\",\"dependencies\":{\"core-js\":\"3.51.0\"}}" > package.json
echo "install:              postinstall ran $(npm install --foreground-scripts 2>&1 | grep -c "core-js@3.51.0 postinstall") time(s)"
npm install-scripts approve core-js >/dev/null 2>&1
echo "after approve:        allowScripts=$(node -p "JSON.stringify(require(\"./package.json\").allowScripts)")"
rm -rf node_modules
echo "install again:        postinstall ran $(npm install --foreground-scripts 2>&1 | grep -c "core-js@3.51.0 postinstall") time(s)"
rm -rf node_modules
echo "--ignore-scripts:     postinstall ran $(npm ci --ignore-scripts --foreground-scripts 2>&1 | grep -c "core-js@3.51.0 postinstall") time(s)"
cd "$(mktemp -d)" && echo "{\"name\":\"b\",\"version\":\"1.0.0\"}" > package.json
npm install pnpm --package-lock-only --ignore-scripts --min-release-age=10 >/dev/null 2>&1
echo "min-release-age=10:   npm install pnpm picked $(node -p "require(\"./package-lock.json\").packages[\"node_modules/pnpm\"].version")"
cd "$(mktemp -d)" && echo "{\"name\":\"c\",\"version\":\"1.0.0\",\"dependencies\":{\"is-number\":\"github:jonschlinkert/is-number#98e8ff1\"}}" > package.json
echo "git dependency:       $(npm install --ignore-scripts 2>&1 | grep -m1 "npm error code" || echo "no npm error")"
'

# shellcheck disable=SC2016
pnpm_case='
set -u
npm i -g -s pnpm@12.18.0 >/dev/null 2>&1; echo "=== pnpm $(pnpm -v)"
export CI=true
cd "$(mktemp -d)" && echo "{\"name\":\"a\",\"version\":\"1.0.0\",\"dependencies\":{\"core-js\":\"3.51.0\"}}" > package.json
out=$(pnpm install 2>&1) && rc=0 || rc=$?
echo "install:              exit $rc, $(echo "$out" | grep -m1 -oE "ERR_PNPM_[A-Z_]+|Ignored build scripts: .*" | head -1)"
rm -rf node_modules pnpm-lock.yaml; printf "allowBuilds:\n  core-js: true\n" > pnpm-workspace.yaml
echo "allowBuilds core-js:  postinstall $(pnpm install --reporter=append-only 2>&1 | grep -c "postinstall: Done") time(s)"
cd "$(mktemp -d)" && echo "{\"name\":\"b\",\"version\":\"1.0.0\"}" > package.json
pnpm add pnpm --lockfile-only >/dev/null 2>&1
echo "default (1440 min):   pnpm add pnpm picked $(grep -m1 -oE "^  pnpm@[0-9.]+" pnpm-lock.yaml)"
rm -f pnpm-lock.yaml; echo "{\"name\":\"b\",\"version\":\"1.0.0\"}" > package.json; printf "minimumReleaseAge: 14400\n" > pnpm-workspace.yaml
pnpm add pnpm --lockfile-only >/dev/null 2>&1
echo "minimumReleaseAge 10d: pnpm add pnpm picked $(grep -m1 -oE "^  pnpm@[0-9.]+" pnpm-lock.yaml)"
'

for v in 11.21.2 12.2.2; do docker run --rm -e "V=$v" "$IMAGE" sh -c "$npm_case"; done
docker run --rm "$IMAGE" sh -c "$pnpm_case"
