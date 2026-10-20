#!/usr/bin/env bash
# Update resolver for OmaPhoto.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "1.4.9", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "omaphoto.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="ELY-Open-Source/OmaPhoto"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL --retry 3 --max-time 60 ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags are `v<version>`. The AppImage's name carries no version, so the tag in
# its download URL is what changes from one release to the next. The .deb,
# .rpm and Arch packages beside it link the distribution's Qt.
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name == "omaphoto-x86_64.AppImage") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] && [ "$url" != "null" ] || {
  echo "failed to resolve omaphoto release" >&2
  exit 1
}
echo "resolved omaphoto $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"omaphoto.AppImage", url:$u}]}'
