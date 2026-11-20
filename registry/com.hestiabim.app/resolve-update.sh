#!/usr/bin/env bash
# Update resolver for Hestia.
#
# The same GitHub release also ships an AppImage, an rpm, a Windows
# installer and a macOS disk image, plus the web app's static files.
# Take the official amd64 .deb. Among the releases that have it, pick
# the highest version number, not the newest publish date. There is no
# desktop aarch64 archive.
# Prints JSON on stdout:
#   { "version": "0.2.6", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "hestia.deb", "url": "..." } ] }
set -euo pipefail

repo="engdennylsonsantos-cloud/Hestia"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  [ .[] | select((.draft or .prerelease) | not)
        | select(.tag_name | test("^v[0-9]+(\\.[0-9]+)*$"))
        | . as $r
        | .assets[]
        | select(.name | test("^Hestia_[0-9][0-9.]*_amd64\\.deb$"))
        | { published: $r.published_at,
            html: $r.html_url,
            ver: ($r.tag_name | ltrimstr("v")),
            url: .browser_download_url } ]
  | max_by(.ver | split(".") | map(tonumber))')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
url="$(jq -r '.url // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Hestia release" >&2; exit 1; }
echo "resolved Hestia $version ($date)" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[{filename:"hestia.deb", url:$u}]}'
