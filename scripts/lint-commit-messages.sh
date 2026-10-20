#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 BASE_SHA HEAD_SHA" >&2
  exit 2
fi

base_sha="$1"
head_sha="$2"

git cat-file -e "${base_sha}^{commit}"
git cat-file -e "${head_sha}^{commit}"

# Select non-merge commits reachable from HEAD but not from BASE,
# oldest first for convenient log review.
commits="$(git rev-list --reverse --no-merges "$head_sha" "^$base_sha")"

if [[ -z "$commits" ]]; then
  echo "No non-merge commits found in the selected range."
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel)"

failed=0
while IFS= read -r commit; do
  echo "Checking commit: $commit"

  if git show -s --format=%B "$commit" |
    prek exec commitlint -- \
      commitlint --config "$repo_root/config/commitlint.config.cjs"; then
    echo "PASS: $commit"
  else
    echo "FAIL: $commit" >&2
    failed=1
  fi
done <<<"$commits"

exit "$failed"
