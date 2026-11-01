#!/usr/bin/env bash
# Update resolver for SculptForge.
#
# The same GitHub release also ships installers, an AppImage, a single-file
# Flatpak, VFX-platform tarballs, and macOS and Windows archives. Take only
# SculptForge-<version>-linux-x86_64.tar.gz.
# Prints JSON on stdout:
#   { "version": "0.10.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "sculptforge.tar.gz", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="islandmed/SculptForge"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best_published=""
best_version=""
best_date=""
best_url=""

page=1
while [ "$page" -le 4 ]; do
  rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    "https://api.github.com/repos/$repo/releases?per_page=20&page=$page")"
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
    | select(.name | test("^SculptForge-[0-9][0-9.]*-linux-x86_64\\.tar\\.gz$"))
    | [$r.published_at,
       (.name | capture("^SculptForge-(?<v>[0-9][0-9.]*)-linux-x86_64\\.tar\\.gz$").v),
       ($r.published_at[0:10]),
       .browser_download_url]
    | @tsv
  ' <<<"$rels")

  page=$((page + 1))
done

[ -n "$best_version" ] && [ -n "$best_url" ] || { echo "failed to resolve SculptForge release" >&2; exit 1; }
echo "resolved SculptForge $best_version ($best_date): $best_url" >&2

jq -n --arg v "$best_version" --arg d "$best_date" --arg u "$best_url" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"sculptforge.tar.gz", arch:"x86_64", url:$u}
   ]}'
