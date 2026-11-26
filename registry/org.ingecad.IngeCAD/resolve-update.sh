#!/usr/bin/env bash
# Update resolver for IngeCAD.
#
# Prints the current version + the Linux x86_64 tarball as JSON on stdout.
# Logs go to stderr. No hashing — FlatPark downloads the URL and computes
# the extra-data sha256/size. The version is compared against the latest
# <release> in the AppStream metainfo.
#
# Not every GitHub release carries the tarball. v0.6.5, which
# releases/latest currently returns, attaches only the Flatpak bundle and
# the snap. Walk recent releases and take the most recently published one
# that ships IngeCAD-<version>-linux-x86_64.tar.gz.
set -euo pipefail

repo="ingelibre/ingecad"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30")"

picked="$(jq -c '
  [ .[]
    | select(.draft | not) | select(.prerelease | not)
    | . as $r
    | ($r.assets[]? | select(.name | test("linux-x86_64\\.tar\\.gz$"))) as $a
    | {version: ($r.tag_name | ltrimstr("v")),
       published: $r.published_at,
       date: ($r.published_at[0:10]),
       url: $a.browser_download_url}
  ] | sort_by(.published) | last // empty
' <<<"$rels")"

[ -n "$picked" ] || { echo "failed to resolve an ingecad tarball" >&2; exit 1; }

version="$(jq -r '.version' <<<"$picked")"
date="$(jq -r '.date' <<<"$picked")"
url="$(jq -r '.url' <<<"$picked")"
echo "resolved ingecad $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"ingecad.tar.gz", url:$u}]}'
