#!/usr/bin/env bash
# Update resolver for freemkv.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "1.7.7", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "freemkv.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="freemkv/freemkv"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Anchor on the stable-named `freemkv-amd64.deb`: from 1.8.0 upstream drops the
# versioned freemkv-<version>-amd64.deb (freemkv/freemkv#69). The release also
# carries bare binaries, an AppImage, a .flatpak bundle and the macOS/Windows
# builds. The version comes from the tag, and the URL stays per-release.
url="$(jq -r '.assets[] | select(.name == "freemkv-amd64.deb") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve freemkv release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one amd64 .deb asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved freemkv $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"freemkv.deb", url:$u}]}'
