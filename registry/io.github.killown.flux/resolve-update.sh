#!/usr/bin/env bash
# Update resolver for Flux.
#
# Prints the current version + the Linux x86_64 and aarch64 release tarballs
# as JSON:
#   { "version": "0.8.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "flux.tar.gz", "arch": "x86_64", "url": "..." },
#                  { "filename": "flux.tar.gz", "arch": "aarch64", "url": "..." } ] }
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
# The release workflow uploads one tarball per arch named after the tag
# (aarch64 since v0.3.0, killown/flux#34).
asset() {
  jq -r --arg n "flux-$tag-$1.tar.gz" \
    '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1
}
url="$(asset x86_64)"
url_arm="$(asset aarch64)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve flux release" >&2; exit 1; }
[ -n "$url_arm" ] || { echo "no aarch64 tarball in flux $tag" >&2; exit 1; }
echo "resolved flux $version ($date): $url $url_arm" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"flux.tar.gz", arch:"x86_64", url:$u}, {filename:"flux.tar.gz", arch:"aarch64", url:$ua}]}'
