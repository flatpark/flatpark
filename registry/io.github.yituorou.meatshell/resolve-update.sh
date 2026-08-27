#!/usr/bin/env bash
# Update resolver for MeatShell.
#
# Prints the current version + the Linux x86_64 release tarball as JSON on
# stdout:
#   { "version": "0.7.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "meatshell.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="yituorou/meatshell"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Anchor the asset name exactly. The same release also ships
# meatshell-*-linux-x86_64-glibc228.tar.gz (an older-glibc build), an AppImage,
# .deb packages, aarch64 tarballs and a prebuilt .flatpak bundle — a loose
# "*-linux-x86_64*.tar.gz" match would happily pick the wrong one.
url="$(jq -r --arg re "^meatshell-v[^/]+-linux-x86_64\\.tar\\.gz$" \
        '.assets[] | select(.name | test($re)) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve meatshell release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "ambiguous meatshell asset match:" >&2; echo "$url" >&2; exit 1; }
echo "resolved meatshell $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"meatshell.tar.gz", url:$u}]}'
