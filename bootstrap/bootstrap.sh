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
  if [[ -e "$dir" ]]; then echo "skip $name: $dir exists"; continue; fi
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

  if [[ "$MODE" == "--local" ]]; then
    echo "built $dir"
  else
    gh repo create "$ORG/$name" --public --source "$dir" --push \
      --description "merge-gate-lab fleet repo (deliberately insecure, do not deploy)"
    echo "created https://github.com/$ORG/$name"
  fi
done
