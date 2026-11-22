#!/usr/bin/env bash
# Update resolver for Open Calc Studio.
#
# Each GitHub release carries the desktop builds for every platform plus
# SDK, hosted-web and headless-API archives (.zip, .tgz), checksums,
# signatures and CI evidence. Take only Open.Calc.Studio_<version>_amd64.deb.
# Among the non-draft, non-prerelease releases that have that archive, pick the
# highest version number (the 0.x releases sort below the 2026.x ones).
# Prints JSON on stdout:
#   { "version": "2026.46.1", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "open-calc-studio.deb", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting: update-pins reads the
# asset's size and digest from the releases API.
set -euo pipefail

repo="OpenAEC-Foundation/open-calc-studio"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=30" | jq '
  [ .[] | select((.draft or .prerelease) | not) | . as $r
    | .assets[]
    | select(.name | test("^Open\\.Calc\\.Studio_[0-9][0-9.]*_amd64\\.deb$"))
    | { published: $r.published_at,
        html: $r.html_url,
        url: .browser_download_url,
        ver: (.name | capture("^Open\\.Calc\\.Studio_(?<v>[0-9][0-9.]*)_amd64\\.deb$").v) } ]
  | max_by(.ver | split(".") | map(tonumber))')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
url="$(jq -r '.url // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Open Calc Studio release" >&2; exit 1; }
echo "resolved Open Calc Studio $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"open-calc-studio.deb", arch:"x86_64", url:$u}
   ]}'
