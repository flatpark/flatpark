#!/usr/bin/env bash
# Update resolver for Cline Desktop.
#
# The GitHub repo also publishes CLI, SDK and extension releases, and those
# do not carry the Linux desktop .deb. Walk recent releases and take the
# newest non-draft, non-prerelease asset named Cline_<version>_amd64.deb.
# Prints JSON on stdout:
#   { "version": "0.0.48", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "cline.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="cline/cline"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best_published=""
best_version=""
best_date=""
best_url=""

page=1
while [ "$page" -le 4 ]; do
  rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    "https://api.github.com/repos/$repo/releases?per_page=30&page=$page")"
  count="$(jq 'length' <<<"$rels")"
  [ "$count" -gt 0 ] || break

  while IFS="$(printf '\t')" read -r published version date url; do
    [ -n "$published" ] || continue
    if [ -z "$best_published" ] || [ "$published" \> "$best_published" ]; then
      best_published="$published"
      best_version="$version"
      best_date="$date"
      best_url="$url"
    fi
  done < <(jq -r '
    .[] | select(.draft | not) | select(.prerelease | not) | . as $r
    | .assets[]
    | select(.name | test("^Cline_[0-9.]+_amd64\\.deb$"))
    | [$r.published_at,
       (.name | capture("^Cline_(?<v>[0-9.]+)_amd64\\.deb$").v),
       ($r.published_at[0:10]),
       .browser_download_url]
    | @tsv
  ' <<<"$rels")

  page=$((page + 1))
done

[ -n "$best_version" ] && [ -n "$best_url" ] || { echo "failed to resolve Cline desktop release" >&2; exit 1; }
echo "resolved Cline $best_version ($best_date): $best_url" >&2

jq -n --arg v "$best_version" --arg d "$best_date" --arg u "$best_url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"cline.deb", url:$u}]}'
