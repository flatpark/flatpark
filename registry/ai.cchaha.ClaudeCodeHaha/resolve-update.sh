#!/usr/bin/env bash
# Update resolver for Claude Code Haha.
#
# Prints the current version + the x86_64 Linux .deb as JSON on stdout:
#   { "version": "0.5.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "cc-haha.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="NanmiCoder/cc-haha"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The x86_64 desktop build is `Claude-Code-Haha-<ver>-linux-amd64.deb`. Match it
# exactly so the AppImage, the .rpm and the arm64, macOS and Windows assets are
# all excluded.
url="$(jq -r '.assets[] | select(.name | test("-linux-amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
url_arm="$(jq -r '.assets[] | select(.name | test("-linux-arm64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
[ -n "$url_arm" ] || { echo "no aarch64 build in this release" >&2; exit 1; }

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Claude Code Haha release" >&2; exit 1; }
echo "resolved Claude Code Haha $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"cc-haha.deb", arch:"x86_64", url:$u}, {filename:"cc-haha.deb", arch:"aarch64", url:$ua}]}'
