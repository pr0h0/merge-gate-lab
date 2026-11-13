#!/usr/bin/env bash
# Rewrite every `uses: owner/repo[/path]@<tag or branch>` in .github/workflows/*.y*ml of the
# current directory to `@<full commit SHA> # <most specific tag on that commit>`.
# Skips local (./) and docker:// references and refs that already are a full SHA.
# Needs gh and jq. Run it in a repo checkout, or through fleet-pr.sh for every repo.
#
#   ./pin-actions.sh
set -euo pipefail
shopt -s nullglob
declare -A cache
for f in .github/workflows/*.yml .github/workflows/*.yaml; do
  while read -r ref; do
    [[ -n "${cache[$ref]:-}" ]] && continue
    action="${ref%@*}" tag="${ref#*@}"
    repo=$(cut -d/ -f1-2 <<<"$action")
    sha=$(gh api "repos/$repo/commits/$tag" --jq .sha)
    # The tags endpoint lists each tag's commit; take the longest name on our commit (v7 -> v7.0.1).
    best=$(gh api --paginate "repos/$repo/tags?per_page=100" --jq ".[] | select(.commit.sha == \"$sha\") | .name" \
      | awk '{ print length, $0 }' | sort -rn | head -1 | cut -d' ' -f2-)
    cache[$ref]="$action@$sha # ${best:-$tag}"
    echo "$ref -> ${cache[$ref]}" >&2
  done < <(grep -oE 'uses:[[:space:]]+[^[:space:]#]+@[^[:space:]#]+' "$f" | awk '{print $2}' \
             | grep -vE '^(\./|docker://)' | grep -vE '@[0-9a-f]{40}$' | sort -u)
  for ref in "${!cache[@]}"; do
    # Replace the ref and any old trailing comment on the same line.
    sed -i -E "s|(uses:[[:space:]]+)${ref//./\\.}([[:space:]]*#.*)?\$|\1${cache[$ref]}|" "$f"
  done
done
