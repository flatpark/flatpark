#!/usr/bin/env bash
# Update resolver for thClaws.
#
# Prints the current version + the x86_64 Linux tarball as JSON on stdout:
#   { "version": "0.109.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "thclaws.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="thClaws/thClaws"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The desktop build is `thclaws-v<ver>-x86_64-unknown-linux-gnu.tar.gz`. Match
# the triple exactly so the aarch64, macOS and Windows assets are excluded.
url="$(jq -r '.assets[] | select(.name | test("x86_64-unknown-linux-gnu\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"
url_arm="$(jq -r '.assets[] | select(.name | test("aarch64-unknown-linux-gnu\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"
[ -n "$url_arm" ] || { echo "no aarch64 build in this release" >&2; exit 1; }

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve thClaws release" >&2; exit 1; }
echo "resolved thClaws $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"thclaws.tar.gz", arch:"x86_64", url:$u}, {filename:"thclaws.tar.gz", arch:"aarch64", url:$ua}]}'
