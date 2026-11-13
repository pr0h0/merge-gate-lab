#!/usr/bin/env bash
# Lesson 5.2: fix the lab's two injectable workflows. Run in a repo checkout (or through
# 4.1-dependabot/fleet-pr.sh). Safe to rerun.
#   ci.yml      pull_request_target -> pull_request; drop the head checkout and the fork guard
#               (fork PRs now get a read-only token and no secrets); PR title via env.
#   triage.yml  comment body via env. issue_comment stays: it is what the workflow is for.
# shellcheck disable=SC2016  # the sed scripts below are meant to stay literal
set -euo pipefail
W=.github/workflows
f="$W/ci.yml"
if [[ -f "$f" ]]; then
  sed -i \
    -e '/^# Deliberately weak workflow for merge-gate-lab. Every problem/c\# CI for merge-gate-lab. Runs on pull_request: PR code gets a read-only token and no secrets.' \
    -e '/^# The `if:` guard on each job keeps PRs from forks out/d' \
    -e '/^# be attacked by strangers. Remove the guard/d' \
    -e 's/^  pull_request_target:/  pull_request:/' \
    -e "/^    if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository\$/d" \
    -e '/^          ref: \${{ github.event.pull_request.head.sha || github.sha }}$/d' \
    -e 's/^        run: echo "Tested \${{ github.event.pull_request.title }}"$/        env:\n          TITLE: ${{ github.event.pull_request.title }}\n        run: echo "Tested ${TITLE:-$GITHUB_REF_NAME}"/' \
    "$f"
fi
f="$W/triage.yml"
if [[ -f "$f" ]]; then
  sed -i \
    -e 's/^# Deliberately weak workflow for merge-gate-lab\.$/# Comment triage for merge-gate-lab. The comment body is data: it reaches the shell only through $COMMENT./' \
    -e 's/^  issue_comment:$/  issue_comment: # zizmor: ignore[dangerous-triggers] members-only guard, no token permissions, no secrets/' \
    -e '/^      - name: Parse command$/{n;s/^        run: |$/        env:\n          COMMENT: ${{ github.event.comment.body }}\n        run: |/}' \
    -e 's/^          echo "Comment: \${{ github.event.comment.body }}"$/          echo "Comment: $COMMENT"/' \
    "$f"
fi
