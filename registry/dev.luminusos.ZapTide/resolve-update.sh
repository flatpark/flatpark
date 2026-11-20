#!/usr/bin/env bash
# Update resolver for ZapTide.
#
# Prints the current stable version + both x86_64 and aarch64 Linux release
# tarballs as JSON on stdout:
#   { "version": "0.9.0", "releaseDate": "YYYY-MM-DD",
#     "releaseUrl": "https://github.com/luminusOS/zaptide/releases/tag/v0.9.0",
#     "sources": [ { "filename": "zaptide.tar.gz", "arch": "x86_64", "url": "..." },
#                  { "filename": "zaptide.tar.gz", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark fetches the
# URLs and computes the extra-data sha256/size at update time.
set -euo pipefail

repo="luminusOS/zaptide"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest returns the newest non-prerelease tag (skipping -rc builds).
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
notes_url="$(jq -r '.html_url' <<<"$rel")"

asset_url() {
  jq -r --arg re "$1" '.assets[] | select(.name | test($re)) | .browser_download_url' <<<"$rel" | head -n1
}
url_x86_64="$(asset_url '^zaptide-v[0-9.]+-x86_64-linux-gnu\.tar\.gz$')"
url_arm64="$(asset_url '^zaptide-v[0-9.]+-aarch64-linux-gnu\.tar\.gz$')"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url_x86_64" ] && [ -n "$url_arm64" ] || {
  echo "failed to resolve ZapTide release" >&2
  exit 1
}
echo "resolved ZapTide $version ($date): $url_x86_64" >&2

jq -n --arg v "$version" --arg d "$date" --arg n "$notes_url" \
      --arg ux "$url_x86_64" --arg ua "$url_arm64" \
  '{version:$v, releaseDate:$d, releaseUrl:$n, sources:[
     {filename:"zaptide.tar.gz", arch:"x86_64",  url:$ux},
     {filename:"zaptide.tar.gz", arch:"aarch64", url:$ua}
   ]}'
