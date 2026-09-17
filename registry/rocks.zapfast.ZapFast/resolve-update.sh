#!/usr/bin/env bash
# Update resolver for ZapFast.
#
# Prints the current version + the official Linux release tarballs as JSON on
# stdout:
#   { "version": "0.14.0", "releaseDate": "YYYY-MM-DD",
#     "releaseUrl": "https://github.com/crmne/zapfast/releases/tag/v0.14.0",
#     "sources": [ { "filename": "zapfast-x86_64.tar.gz",  "url": "..." },
#                  { "filename": "zapfast-aarch64.tar.gz", "url": "..." } ] }
# releaseUrl becomes the <url type="details"> of the new metainfo <release>, so
# the app page links at upstream's own notes for the version it ships.
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URLs and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="crmne/zapfast"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest is the newest non-prerelease tag; ZapFast tags every release
# as v<major>.<minor>.<patch>.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
notes_url="$(jq -r '.html_url' <<<"$rel")"

# The Linux bundles are zapfast-v<ver>-x86_64-unknown-linux-gnu.tar.gz and the
# aarch64 equivalent. Match them exactly so the .deb, the .rpm, the Windows
# .zip/.exe, the macOS .dmg and the upstream .flatpak are all excluded.
asset_url() {
  jq -r --arg re "$1" '.assets[] | select(.name | test($re)) | .browser_download_url' <<<"$rel" | head -n1
}
url_x86_64="$(asset_url '^zapfast-v[0-9.]+-x86_64-unknown-linux-gnu\.tar\.gz$')"
url_arm64="$(asset_url '^zapfast-v[0-9.]+-aarch64-unknown-linux-gnu\.tar\.gz$')"

[ -n "$version" ] && [ -n "$url_x86_64" ] && [ -n "$url_arm64" ] || {
  echo "failed to resolve ZapFast release" >&2
  exit 1
}
echo "resolved ZapFast $version ($date): $url_x86_64" >&2

jq -n --arg v "$version" --arg d "$date" --arg n "$notes_url" \
      --arg ux "$url_x86_64" --arg ua "$url_arm64" \
  '{version:$v, releaseDate:$d, releaseUrl:$n, sources:[
     {filename:"zapfast-x86_64.tar.gz",  url:$ux},
     {filename:"zapfast-aarch64.tar.gz", url:$ua}
   ]}'
