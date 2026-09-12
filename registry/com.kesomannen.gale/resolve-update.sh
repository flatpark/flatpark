#!/usr/bin/env bash
# Update resolver for Gale.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "1.22.2", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "gale.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="Kesomannen/gale"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags are bare versions, with no `v` prefix.
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux build we package is `Gale_<version>_amd64.deb`; the .rpm, the
# AppImage and the minisign .sig beside each of them are skipped. Anchored on
# the exact name so neither a stray asset nor the `.deb.sig` can match.
url="$(jq -r --arg v "$version" \
        '.assets[] | select(.name == "Gale_\($v)_amd64.deb") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve gale release" >&2; exit 1; }
echo "resolved gale $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"gale.deb", url:$u}]}'
