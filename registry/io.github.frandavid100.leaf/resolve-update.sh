#!/usr/bin/env bash
# Update resolver for Leaf.
#
# Prints the newest release + the x86_64 app-tree tarball as JSON on stdout:
#   { "version": "0.1.0-alpha.27", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "leaf-app.tar.xz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting: update-pins reads the
# asset's digest and size from the releases API. The version is compared
# against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="frandavid100/leaf"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Every Leaf release so far is a prerelease (0.1.0-alpha.N), and upstream asked
# for those to be followed (flatpark#994), so this reads the release list, not
# releases/latest, which skips prereleases and would return nothing. Drafts are
# never listed to anonymous callers but are filtered anyway; the list is newest
# first, and only a release that carries the FlatPark tarball counts, so a
# release published without it keeps the current pin instead of failing.
rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=20")"

# Per release: the .flatpak bundle for direct download, checksums, smoke logs,
# and Leaf-<version>-flatpark-x86_64.tar.xz, the /app tree out of upstream's
# own flatpak build, published for this package. Only that one is staged here.
rel="$(jq -c '[.[] | select(.draft | not)
               | select(any(.assets[]; .name | test("^Leaf-.+-flatpark-x86_64\\.tar\\.xz$")))][0] // empty' <<<"$rels")"
[ -n "$rel" ] || { echo "no leaf release carries a -flatpark-x86_64.tar.xz asset" >&2; exit 1; }

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name | test("^Leaf-.+-flatpark-x86_64\\.tar\\.xz$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve leaf release" >&2; exit 1; }
echo "resolved leaf $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"leaf-app.tar.xz", url:$u}]}'
