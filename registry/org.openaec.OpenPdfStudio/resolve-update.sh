#!/usr/bin/env bash
# Update resolver for Open PDF Studio.
#
# The same GitHub release also ships an AppImage, a snap, Windows, macOS and
# a small Python package. Take only Open.PDF.Studio_<version>_amd64.deb.
# Among the releases that have that archive, pick the highest version number,
# not the newest publish date.
# Prints JSON on stdout:
#   { "version": "2026.45.0", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "open-pdf-studio.deb", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="OpenAEC-Foundation/open-pdf-studio"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  [ .[] | select((.draft or .prerelease) | not) | . as $r
    | .assets[]
    | select(.name | test("^Open\\.PDF\\.Studio_[0-9][0-9.]*_amd64\\.deb$"))
    | { published: $r.published_at,
        html: $r.html_url,
        url: .browser_download_url,
        ver: (.name | capture("^Open\\.PDF\\.Studio_(?<v>[0-9][0-9.]*)_amd64\\.deb$").v) } ]
  | max_by(.ver | split(".") | map(tonumber))')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
url="$(jq -r '.url // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Open PDF Studio release" >&2; exit 1; }
echo "resolved Open PDF Studio $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"open-pdf-studio.deb", arch:"x86_64", url:$u}
   ]}'
