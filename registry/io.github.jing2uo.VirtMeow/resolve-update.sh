#!/usr/bin/env bash
# Update resolver for virt-meow.
#
# Prints the current version + the Linux GUI binary of each arch as JSON:
#   { "version": "0.1.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "virt-mm-linux", "arch": "x86_64", "url": "..." }, … ] }
# Logs go to stderr. The version is compared against the latest <release> in
# the AppStream metainfo.
set -euo pipefail

repo="jing2uo/virt-meow"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The release names these assets the same in every version (its
# CONTRIBUTING.md, "Releasing"). Match the exact names: the CLI-only archives
# (virt-mm_<version>_linux_<arch>.tar.gz) carry no GUI.
asset() { jq -r --arg n "$1" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1; }
url="$(asset virt-mm-linux-x86_64)"
url_arm="$(asset virt-mm-linux-aarch64)"

[ -n "$version" ] && [ -n "$url" ] && [ -n "$url_arm" ] \
  || { echo "failed to resolve virt-meow release" >&2; exit 1; }
echo "resolved virt-meow $version ($date): $url $url_arm" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"virt-mm-linux", arch:"x86_64", url:$u},
     {filename:"virt-mm-linux", arch:"aarch64", url:$ua}]}'
