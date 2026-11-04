#!/usr/bin/env bash
# Update resolver for Open CAD Studio.
#
# Prints the current version + the Linux x86_64 AppImage as JSON on stdout:
#   { "version": "2026.38", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "opencadstudio.AppImage", "url": "...",
#                    "size": N, "sha256": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. size + sha256 come
# from GitHub's asset metadata: upstream has re-uploaded the AppImage under the
# same tag with the same byte count (v2026.44, flatpark#977), so the digest is
# what tells update-pins the bytes moved. The version is
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
asset="$(jq -c --arg t "$tag" \
        '[.assets[] | select(.name == "OpenCADStudio-\($t)-linux-x86_64.AppImage")]' <<<"$rel")"
[ "$(jq length <<<"$asset")" -eq 1 ] || { echo "expected exactly one x86_64 AppImage asset, got: $asset" >&2; exit 1; }
url="$(jq -r '.[0].browser_download_url' <<<"$asset")"
size="$(jq -r '.[0].size' <<<"$asset")"
sha256="$(jq -r '.[0].digest // "" | ltrimstr("sha256:")' <<<"$asset")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Open CAD Studio release" >&2; exit 1; }
echo "resolved opencadstudio $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --argjson s "$size" --arg h "$sha256" \
  '{version:$v, releaseDate:$d,
    sources:[{filename:"opencadstudio.AppImage", url:$u, size:$s} + (if $h == "" then {} else {sha256:$h} end)]}'
