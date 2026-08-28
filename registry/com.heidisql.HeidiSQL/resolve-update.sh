#!/usr/bin/env bash
# Update resolver for HeidiSQL.
#
# Prints the current version + the Linux x86_64 qt6 tarball as JSON on stdout:
#   { "version": "12.21", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "heidisql.tgz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Only the app payload is resolved. libQt6Pas and the prebuilt SQL client stack
# are pinned by hand outside the managed block in the manifest, and are migrated
# deliberately rather than on upstream's release cadence.
set -euo pipefail

repo="HeidiSQL/HeidiSQL"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Every release carries five Linux artifacts. The one packaged here is the
# x86_64 qt6 widgetset build, `build-qt6-v<version>.tgz` — anchoring on the
# digit after the optional `v` is what keeps `build-qt6-arm64-v<version>.tgz`
# out (the tag prefix alone matches both), and the `v` is optional because
# upstream shipped 12.17 without it. The .deb/.rpm carry the same binary, the
# qt5 and gtk2 tarballs are the other widgetsets, and the Windows and macOS
# builds are skipped.
url="$(jq -r '.assets[] | select(.name | test("^build-qt6-v?[0-9][0-9.]*\\.tgz$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve heidisql release" >&2; exit 1; }
echo "resolved heidisql $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"heidisql.tgz", url:$u}]}'
