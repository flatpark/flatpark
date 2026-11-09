#!/usr/bin/env bash
# Update resolver for ConstructCraft (formerly ConstructCAD).
#
# The same GitHub release also ships installers, AppImages, .deb packages and
# macOS and Windows archives. Take only
# constructcraft-v<version>-<arch>-unknown-linux-gnu.tar.gz for x86_64 and
# aarch64, from the newest release that has both.
# Prints JSON on stdout:
#   { "version": "0.10.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "constructcraft.tar.gz", "arch": "x86_64",  "url": "..." },
#                  { "filename": "constructcraft.tar.gz", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting.
set -euo pipefail

repo="francisreboucas/constructcraft"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=30")"

# Newest non-draft, non-prerelease release carrying both Linux tarballs.
rel="$(jq -c '
  def tarball($a): "^constructcraft-v[0-9.]+-" + $a + "-unknown-linux-gnu\\.tar\\.gz$";
  [ .[] | select(.draft | not) | select(.prerelease | not)
    | select(any(.assets[]; .name | test(tarball("x86_64"))))
    | select(any(.assets[]; .name | test(tarball("aarch64")))) ]
  | sort_by(.published_at) | last // empty
' <<<"$rels")"
[ -n "$rel" ] || { echo "failed to resolve ConstructCraft release" >&2; exit 1; }

asset_url() {
  jq -r --arg a "$1" '
    [ .assets[] | select(.name | test("^constructcraft-v[0-9.]+-" + $a + "-unknown-linux-gnu\\.tar\\.gz$")) ]
    | first | .browser_download_url' <<<"$rel"
}

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at[0:10]' <<<"$rel")"
url_x86_64="$(asset_url x86_64)"
url_aarch64="$(asset_url aarch64)"
echo "resolved ConstructCraft $version ($date): $url_x86_64 $url_aarch64" >&2

jq -n --arg v "$version" --arg d "$date" --arg ux "$url_x86_64" --arg ua "$url_aarch64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"constructcraft.tar.gz", arch:"x86_64",  url:$ux},
     {filename:"constructcraft.tar.gz", arch:"aarch64", url:$ua}
   ]}'
