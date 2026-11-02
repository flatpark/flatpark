#!/usr/bin/env bash
# Update resolver for PhotonCAM.
#
# Older tags shipped this project as LaserBurn-*.tar.gz. Take only
# PhotonCAM-<version>-linux-x86_64.tar.gz. Among the releases that have that
# archive, pick the highest version number, not the newest publish date: a
# later patch to an older line would otherwise downgrade the pin.
# Prints JSON on stdout:
#   { "version": "1.2.8", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "photoncam.tar.gz", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="pietini69/photoncam"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  [ .[] | select((.draft or .prerelease) | not) | . as $r
    | .assets[]
    | select(.name | test("^PhotonCAM-[0-9]+(\\.[0-9]+)*-linux-x86_64\\.tar\\.gz$"))
    | { published: $r.published_at,
        html: $r.html_url,
        url: .browser_download_url,
        ver: (.name | capture("^PhotonCAM-(?<v>[0-9]+(\\.[0-9]+)*)-linux-x86_64\\.tar\\.gz$").v) } ]
  | max_by(.ver | split(".") | map(tonumber))')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
url="$(jq -r '.url // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve PhotonCAM release" >&2; exit 1; }
echo "resolved PhotonCAM $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"photoncam.tar.gz", arch:"x86_64", url:$u}
   ]}'
