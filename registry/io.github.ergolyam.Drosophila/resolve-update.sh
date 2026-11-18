#!/usr/bin/env bash
# Update resolver for Drosophila.
#
# Prints the current version + the Linux glibc x86_64 and aarch64 release
# executables as JSON:
#   { "version": "2.2.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "drosophila", "arch": "x86_64", "url": "..." },
#                  { "filename": "drosophila", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr.
set -euo pipefail

repo="ergolyam/Drosophila"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name' <<<"$rel")"
version="${tag#v}"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# One bare executable per libc and arch, named after the tag. The glibc
# build is the one that runs on the GNOME runtime.
asset() {
  jq -r --arg n "Drosophila-$tag-linux-glibc-$1" \
    '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1
}
url="$(asset x86_64)"
url_arm="$(asset aarch64)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve drosophila release" >&2; exit 1; }
[ -n "$url_arm" ] || { echo "no glibc aarch64 executable in drosophila $tag" >&2; exit 1; }
echo "resolved drosophila $version ($date): $url $url_arm" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"drosophila", arch:"x86_64", url:$u}, {filename:"drosophila", arch:"aarch64", url:$ua}]}'
