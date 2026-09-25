#!/usr/bin/env bash
# Update resolver for Open CAD Studio.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "2026.38", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "opencadstudio.AppImage", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="HakanSeven12/OpenCADStudio"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name' <<<"$rel")"
version="${tag#v}"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact name, anchored on the tag: the release also carries a snap and the
# Windows installer and portable build.
url="$(jq -r --arg t "$tag" \
        '.assets[] | select(.name == "OpenCADStudio-\($t)-linux-x86_64.AppImage") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Open CAD Studio release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one x86_64 AppImage asset, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved opencadstudio $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"opencadstudio.AppImage", url:$u}]}'
