#!/usr/bin/env bash
# Update resolver for Gyroflow.
#
# Prints the current version + the Linux x86_64 tarball as JSON on stdout:
#   { "version": "1.6.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "gyroflow.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="gyroflow/gyroflow"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest skips the nightlies, which upstream publishes as prereleases.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact name: the release also carries the AppImage, the macOS/Windows builds
# and an .apk, which a loose `linux` match would pick up.
url="$(jq -r '.assets[] | select(.name == "Gyroflow-linux64.tar.gz") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve gyroflow release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one Linux tarball, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved gyroflow $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"gyroflow.tar.gz", url:$u}]}'
