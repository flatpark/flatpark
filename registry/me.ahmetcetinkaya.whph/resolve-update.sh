#!/usr/bin/env bash
# Update resolver for WHPH.
#
# Prints the current version + the Linux x86_64 tarball as JSON on stdout:
#   { "version": "0.24.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "whph.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="ahmet-cetinkaya/whph"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact name: the release also carries upstream's own .flatpak bundle, an APK
# and the Windows builds.
url="$(jq -r --arg v "$version" '.assets[] | select(.name == "whph-v\($v)-linux.tar.gz") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve whph release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one linux tarball, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved whph $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"whph.tar.gz", url:$u}]}'
