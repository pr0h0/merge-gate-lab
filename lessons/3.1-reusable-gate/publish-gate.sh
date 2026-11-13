#!/usr/bin/env bash
# Publish a version of the security gate to $ORG/security-workflows.
#   First run: creates the public repo, gives the security team write access and pushes the
#   files straight to main (the repo has no ruleset yet).
#   Later runs: puts the files on the branch `gate-update` and opens a PR, so the gate's
#   self-test runs the new version and the security team reviews it before anyone uses it.
# Needs gh (org owner, `workflow` scope) and git.
#
#   ORG=<your-test-org> ./publish-gate.sh <gate-dir> "<commit message>"
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
SRC="$(cd "${1:?usage: publish-gate.sh <gate-dir> <message>}" && pwd)"
MSG="${2:-Update the security gate}"
REPO="$ORG/security-workflows"
TEAM="${TEAM:-security}"
BRANCH="gate-update"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
g() { git -C "$work" -c credential.helper= -c credential.helper='!gh auth git-credential' "$@"; }

copy_files() {
  find "$work" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -r "$SRC/." "$work/"
  sed -i.bak "s|@ORG/|@$ORG/|g" "$work/.github/CODEOWNERS" && rm "$work/.github/CODEOWNERS.bak"
}

if ! gh repo view "$REPO" >/dev/null 2>&1; then
  gh repo create "$REPO" --public --description "Central security gate, called by every repo in the org" >/dev/null
  gh api -X PUT "orgs/$ORG/teams/$TEAM/repos/$REPO" -f permission=push --silent
  g init -q -b main
  copy_files
  g add -A && g commit -q -m "$MSG"
  g push -q "https://github.com/$REPO.git" main
  echo "created https://github.com/$REPO"
  exit 0
fi

g clone -q "https://github.com/$REPO.git" .
g checkout -q -B "$BRANCH"
copy_files
g add -A
if g diff --cached --quiet; then echo "no changes: $REPO main already has these files"; exit 0; fi
g commit -q -m "$MSG"
g push -q -f origin "$BRANCH"
pr=$(gh pr list -R "$REPO" --head "$BRANCH" --state open --json url --jq '.[0].url')
if [[ -n "$pr" ]]; then
  echo "updated $pr"
else
  gh pr create -R "$REPO" --head "$BRANCH" --base main --title "$MSG" \
    --body "New version of the security gate. self-test.yml runs it on this PR. Tag the merge commit after merging."
fi
