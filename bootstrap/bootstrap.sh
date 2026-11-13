#!/usr/bin/env bash
# Create the lab fleet: one public repo per name in your TEST org, each built from
# lab-template/ with a short history that includes a leaked (fake) token.
#
#   ./bootstrap/bootstrap.sh <test-org>            create the repos on GitHub
#   ./bootstrap/bootstrap.sh <test-org> --local    only build them under ./fleet/ (no GitHub calls)
#
# Use a throwaway org you own. Never point this at a real company org.
set -euo pipefail

ORG="${1:?usage: bootstrap.sh <test-org> [--local]}"
MODE="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/fleet"
REPOS=(payments-api orders-api marketing-site internal-admin legacy-cron)

if [[ "$MODE" != "--local" ]]; then
  command -v gh >/dev/null || { echo "gh CLI is required" >&2; exit 1; }
  gh api "orgs/$ORG" --jq .login >/dev/null || { echo "org $ORG not found or no access" >&2; exit 1; }
fi

mkdir -p "$OUT"
for name in "${REPOS[@]}"; do
  dir="$OUT/$name"
  if [[ -e "$dir" ]]; then
    echo "reuse $dir"
  else
    cp -r "$ROOT/lab-template" "$dir"
    sed -i.bak "s/\"name\": \"orders-api\"/\"name\": \"$name\"/" "$dir/package.json" && rm "$dir/package.json.bak"
    sed -i.bak "s/^# orders-api/# $name/" "$dir/README.md" && rm "$dir/README.md.bak"

    git -C "$dir" init -q -b main
    git -C "$dir" add -A
    git -C "$dir" -c user.name=lab -c user.email=lab@example.invalid commit -q -m "Initial commit"

    # The mistake every fleet has: a token committed, then "removed" in the next commit.
    # It is random and fake, but shaped so secret scanners flag it.
    token="$(head -c 20 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    printf 'PORT=3000\nINTERNAL_API_TOKEN=%s\n' "$token" > "$dir/.env"
    git -C "$dir" add .env
    git -C "$dir" -c user.name=lab -c user.email=lab@example.invalid commit -q -m "Add local config"
    git -C "$dir" rm -q .env
    printf '.env\n' >> "$dir/.gitignore"
    git -C "$dir" add .gitignore
    git -C "$dir" -c user.name=lab -c user.email=lab@example.invalid commit -q -m "Remove .env from the repo"

    echo "built $dir"
  fi
  [[ "$MODE" == "--local" ]] && continue

  # Safe to rerun: an existing repo is created only once, and pushed to only while it is empty.
  if gh repo view "$ORG/$name" >/dev/null 2>&1; then
    if gh api "repos/$ORG/$name/branches/main" --silent 2>/dev/null; then
      echo "skip $ORG/$name: already has a main branch"; continue
    fi
  else
    gh repo create "$ORG/$name" --public \
      --description "merge-gate-lab fleet repo (deliberately insecure, do not deploy)" >/dev/null
  fi
  # Push over HTTPS with gh's credentials, so it works without SSH keys.
  git -C "$dir" -c credential.helper= -c credential.helper='!gh auth git-credential' \
    push -q "https://github.com/$ORG/$name.git" main
  echo "pushed https://github.com/$ORG/$name"
done
