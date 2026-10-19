#!/usr/bin/env bash
# Update resolver for Flux.
#
# Prints the current version + the Linux x86_64 release tarball as JSON:
#   { "version": "0.2.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "flux.tar.gz", "url": "..." } ] }
# Logs go to stderr.
set -euo pipefail

repo="killown/flux"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name' <<<"$rel")"
version="${tag#v}"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The release workflow uploads one tarball named after the tag.
url="$(jq -r --arg n "flux-$tag-x86_64.tar.gz" \
        '.assets[] | select(.name == $n) | .browser_download_url' \
        <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve flux release" >&2; exit 1; }
echo "resolved flux $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"flux.tar.gz", url:$u}]}'
