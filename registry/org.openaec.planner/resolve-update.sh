#!/usr/bin/env bash
# Update resolver for Open Planner Studio.
#
# Each GitHub release carries a deb, rpm, AppImage, snap, Windows and macOS
# builds, updater signatures and an MCP bundle (.mcpb). Take only
# Open.Planner.Studio_<version>_amd64.deb, from releases/latest: every release
# carries it, so a missing one fails instead of settling on an older release.
# Prints JSON on stdout:
#   { "version": "2026.47.0", "releaseDate": "YYYY-MM-DD", "releaseUrl": "...",
#     "sources": [ { "filename": "open-planner-studio.deb", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="OpenAEC-Foundation/open-planner-studio"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

best="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest" | jq '
  [ . as $r
    | .assets[]
    | select(.name | test("^Open\\.Planner\\.Studio_[0-9][0-9.]*_amd64\\.deb$"))
    | { published: $r.published_at,
        html: $r.html_url,
        url: .browser_download_url,
        ver: (.name | capture("^Open\\.Planner\\.Studio_(?<v>[0-9][0-9.]*)_amd64\\.deb$").v) } ]
  | if length == 1 then .[0] else null end')"

version="$(jq -r '.ver // empty' <<<"$best")"
date="$(jq -r '.published // empty' <<<"$best" | cut -c1-10)"
release_url="$(jq -r '.html // empty' <<<"$best")"
url="$(jq -r '.url // empty' <<<"$best")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Open Planner Studio release" >&2; exit 1; }
echo "resolved Open Planner Studio $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --arg u "$url" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"open-planner-studio.deb", arch:"x86_64", url:$u}
   ]}'
