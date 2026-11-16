#!/usr/bin/env bash
# Update resolver for MitCad.
#
# The same GitHub release also ships Windows archives, a macOS disk image
# and a separate browser zip. Take the official Linux x86_64 AppImage.
# Among the releases that have it, pick the highest version number, not
# the newest publish date. There is no desktop aarch64 archive.
# Prints JSON on stdout:
#   { "version": "0.64.0", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "mitcad.AppImage", "url": "..." } ] }
set -euo pipefail

repo="mitcad/Mitcad"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  [ .[] | select((.draft or .prerelease) | not)
        | select(.tag_name | test("^v[0-9]+(\\.[0-9]+)*$"))
        | . as $r
        | .assets[]
        | select(.name | test("^Mitcad-[0-9][0-9.]*-x86_64\\.AppImage$"))
        | { published: $r.published_at,
            html: $r.html_url,
            ver: ($r.tag_name | ltrimstr("v")),
            url: .browser_download_url } ]
  | max_by(.ver | split(".") | map(tonumber))')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
url="$(jq -r '.url // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve MitCad release" >&2; exit 1; }
echo "resolved MitCad $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[{filename:"mitcad.AppImage", url:$u}]}'
