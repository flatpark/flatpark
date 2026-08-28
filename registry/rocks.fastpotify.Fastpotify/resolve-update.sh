#!/usr/bin/env bash
# Update resolver for Fastpotify.
#
# Prints the current version + the official Linux release tarballs as JSON on
# stdout:
#   { "version": "0.1.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "fastpotify-x86_64.tar.gz",  "url": "..." },
#                  { "filename": "fastpotify-aarch64.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URLs and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="crmne/fastpotify"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest is the newest non-prerelease tag; Fastpotify tags every
# release as v<major>.<minor>.<patch>.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

# The Linux bundles are fastpotify-v<ver>-x86_64-unknown-linux-gnu.tar.gz and
# the aarch64 equivalent. Match them exactly so the Windows .zip and the macOS
# .dmg are excluded.
asset_url() {
  jq -r --arg re "$1" '.assets[] | select(.name | test($re)) | .browser_download_url' <<<"$rel" | head -n1
}
url_x86_64="$(asset_url '^fastpotify-v[0-9.]+-x86_64-unknown-linux-gnu\.tar\.gz$')"
url_arm64="$(asset_url '^fastpotify-v[0-9.]+-aarch64-unknown-linux-gnu\.tar\.gz$')"

[ -n "$version" ] && [ -n "$url_x86_64" ] && [ -n "$url_arm64" ] || {
  echo "failed to resolve Fastpotify release" >&2
  exit 1
}
echo "resolved Fastpotify $version ($date): $url_x86_64" >&2

jq -n --arg v "$version" --arg d "$date" --arg ux "$url_x86_64" --arg ua "$url_arm64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"fastpotify-x86_64.tar.gz",  url:$ux},
     {filename:"fastpotify-aarch64.tar.gz", url:$ua}
   ]}'
