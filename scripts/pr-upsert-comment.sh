#!/usr/bin/env bash
# Create-or-update the PR's preview comment, keyed by a hidden marker so it
# never clobbers another bot's comment (the CI report upserts the same way,
# see post-report.js). Usage: pr-upsert-comment.sh <pr> <body-file>.
# Env: GH_TOKEN, GITHUB_REPOSITORY.
set -euo pipefail

pr="${1:?usage: pr-upsert-comment.sh <pr> <body-file>}"
body="${2:?usage: pr-upsert-comment.sh <pr> <body-file>}"
marker="<!-- wasinix-preview -->"

merged=$(mktemp)
{
  echo "$marker"
  cat "$body"
} >"$merged"

cid=$(gh api "repos/$GITHUB_REPOSITORY/issues/$pr/comments" --paginate \
  --jq "[.[] | select(.body | startswith(\"$marker\"))][0].id // empty")
if [ -n "$cid" ]; then
  gh api -X PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$cid" -F body=@"$merged" >/dev/null
else
  gh pr comment "$pr" --repo "$GITHUB_REPOSITORY" --body-file "$merged"
fi
