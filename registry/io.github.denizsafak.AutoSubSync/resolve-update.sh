#!/usr/bin/env bash
# Update resolver for AutoSubSync: prints the latest release and its Linux
# x86_64 tarball as JSON on stdout. Logs go to stderr.
set -euo pipefail

repo="denizsafak/AutoSubSync"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact match: releases also carry the AppImage and the macOS/Windows zips.
url="$(jq -r '.assets[] | select(.name == "AutoSubSync-linux-amd64.tar.gz") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve AutoSubSync release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one linux-amd64 tarball, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved AutoSubSync $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"autosubsync.tar.gz", url:$u}]}'
