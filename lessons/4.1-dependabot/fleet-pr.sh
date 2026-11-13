#!/usr/bin/env bash
# Open one PR per fleet repo with whatever a command changes in a fresh clone.
# The command runs inside the clone (env: ORG, REPO). Repos where it changes nothing, or
# with an open PR from the same branch, are skipped. Safe to rerun. Skips security-workflows.
# Needs gh (`workflow` scope if the command touches .github/workflows) and git.
#
#   ORG=<your-test-org> ./fleet-pr.sh <branch> "<title>" '<command>' [repo ...]
#   e.g. ./fleet-pr.sh dependabot-config "Add Dependabot version updates" \
#          'mkdir -p .github && sed "s|@ORG@|$ORG|g" ~/lab/dependabot.yml.template > .github/dependabot.yml'
set -euo pipefail
: "${ORG:?set ORG=<your-org>}"
BRANCH="${1:?usage: fleet-pr.sh <branch> <title> <command> [repo ...]}"
TITLE="${2:?title}"
CMD="${3:?command}"
shift 3
repos=("$@")
if [[ ${#repos[@]} -eq 0 ]]; then
  mapfile -t repos < <(gh api --paginate "orgs/$ORG/repos?per_page=100" \
    --jq '.[] | select(.archived | not) | select(.name != "security-workflows") | .name')
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export ORG

for r in "${repos[@]}"; do
  if [[ -n "$(gh pr list -R "$ORG/$r" --head "$BRANCH" --state open --json number --jq '.[].number')" ]]; then
    echo "skip $r: PR from $BRANCH already open"; continue
  fi
  d="$work/$r"
  g() { git -C "$d" -c credential.helper= -c credential.helper='!gh auth git-credential' "$@"; }
  git -c credential.helper= -c credential.helper='!gh auth git-credential' \
    clone -q --depth 1 "https://github.com/$ORG/$r.git" "$d"
  g checkout -q -B "$BRANCH"
  (cd "$d" && REPO="$r" bash -c "$CMD")
  g add -A
  if g diff --cached --quiet; then echo "skip $r: no change"; continue; fi
  g commit -q -m "$TITLE"
  g push -q -f origin "$BRANCH"
  gh pr create -R "$ORG/$r" --head "$BRANCH" --title "$TITLE" --body "Opened by fleet-pr.sh."
done
