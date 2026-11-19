#!/usr/bin/env bash
# Update resolver for Prism: the latest GitHub release and its portable x86_64
# Linux tarball. Prints JSON on stdout, logs to stderr.
set -euo pipefail

repo="Boof2015/prism"

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The portable tarball is `prism-<version>.tar.gz`; anchor on the tag's version
# so the .deb, .rpm, AppImage and macOS/Windows assets never match.
url="$(jq -r --arg n "prism-$version.tar.gz" \
        '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Prism release" >&2; exit 1; }
echo "resolved Prism $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"prism.tar.gz", url:$u}]}'
