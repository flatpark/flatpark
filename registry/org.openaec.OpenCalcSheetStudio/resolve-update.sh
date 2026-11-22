#!/usr/bin/env bash
# Update resolver for Open CalcSheet Studio.
#
# The repository publishes three kinds of release: the app (v<version>), a
# rolling "nightly" prerelease with the same file names, and fem-server-*
# releases of the bundled Open FEM Studio server. App releases also carry an
# openaec-mcp-server source tarball, an AppImage, Windows and macOS builds,
# signatures and checksums. Take only Open.CalcSheet.Studio_<version>_amd64.deb
# from non-draft, non-prerelease releases, and pick the highest version number.
# Prints JSON on stdout:
#   { "version": "2026.47.3", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "open-calcsheet-studio.deb", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="OpenAEC-Foundation/Open-CalcSheet-Studio"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# per_page=100: nightly and fem-server releases come often and would push the
# app's own releases off a short page.
best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=100" | jq '
  [ .[] | select((.draft or .prerelease) | not) | . as $r
    | .assets[]
    | select(.name | test("^Open\\.CalcSheet\\.Studio_[0-9][0-9.]*_amd64\\.deb$"))
    | { published: $r.published_at,
        html: $r.html_url,
        url: .browser_download_url,
        ver: (.name | capture("^Open\\.CalcSheet\\.Studio_(?<v>[0-9][0-9.]*)_amd64\\.deb$").v) } ]
  | max_by(.ver | split(".") | map(tonumber))')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
url="$(jq -r '.url // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Open CalcSheet Studio release" >&2; exit 1; }
echo "resolved Open CalcSheet Studio $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"open-calcsheet-studio.deb", arch:"x86_64", url:$u}
   ]}'
