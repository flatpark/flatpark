#!/usr/bin/env bash
# Update resolver for IMGo.
#
# Prints the current version + the Linux .debs (x86_64 and aarch64) as JSON on
# stdout, one source per arch under the same filename. Logs go to stderr. No
# hashing, no manifest rewriting — FlatPark reads the asset digest and size
# from the releases API and pins without a download. The version is compared
# against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="meowtec/imgo"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Tightly anchored asset names: the release also carries .rpm, .AppImage,
# .flatpak, macOS .dmg and Windows .exe/.zip variants.
x86_64="$(jq -r '.assets[] | select(.name | test("^imgo_[0-9.]+_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
aarch64="$(jq -r '.assets[] | select(.name | test("^imgo_[0-9.]+_arm64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$x86_64" ] && [ -n "$aarch64" ] \
  || { echo "failed to resolve imgo release" >&2; exit 1; }
echo "resolved imgo $version ($date): $x86_64" >&2

jq -n --arg v "$version" --arg d "$date" --arg x "$x86_64" --arg a "$aarch64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"imgo.deb", arch:"x86_64",  url:$x},
     {filename:"imgo.deb", arch:"aarch64", url:$a}
   ]}'
