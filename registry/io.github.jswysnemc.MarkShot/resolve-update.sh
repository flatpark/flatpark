#!/usr/bin/env bash
# Update resolver for Mark Shot.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.1.53", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "mark-shot.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# The Debian pins in the manifest are not resolved here: they follow Debian's
# own uploads rather than Mark Shot's releases, and
# scripts/update-debian-pins.mjs re-resolves them on its own schedule.
set -euo pipefail

repo="jswysnemc/mark-shot"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags are `v<version>`.
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The payload is the self-contained AppImage; the release also carries one .deb
# and .rpm per distribution baseline, all of which link the host's Qt. Matched
# by exact name and anchored on the version so no other asset can be picked.
url="$(jq -r --arg v "$version" \
        '.assets[] | select(.name == "mark-shot-v\($v)-linux-x86_64.AppImage") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] && [ "$url" != "null" ] || {
  echo "failed to resolve mark-shot release" >&2
  exit 1
}
echo "resolved mark-shot $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"mark-shot.AppImage", url:$u}]}'
