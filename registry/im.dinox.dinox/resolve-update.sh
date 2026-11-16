#!/usr/bin/env bash
# Update resolver for DinoX.
#
# DinoX publishes its releases on its own Forgejo (git.dinox.im), next to a
# .sha256 file for every asset. Prints the latest release and its x86_64
# AppImage as JSON on stdout:
#   { "version": "2.3.8", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "dinox.AppImage", "url": "...",
#                    "size": 192121336, "sha256": "..." } ] }
# Logs go to stderr. Forgejo has no per-asset digest field, so the size comes
# from the release's asset list and the sha256 from the .sha256 file upstream
# publishes beside the AppImage; with both, FlatPark pins without downloading
# the 190 MB file, and check-apply-extra still downloads and verifies it.
set -euo pipefail

base="https://git.dinox.im"
repo="dinoxim/dinox"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL "$base/api/v1/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The release also carries a .deb (built for Ubuntu 24.04), a Windows zip, a
# Flatpak bundle and source tarballs. The AppImage brings its own libraries and
# runs on any distribution; match it exactly, without the .sha256 and
# .sources.tar.xz files that share its name.
asset="$(jq -c '[.assets[] | select(.name | test("^DinoX-[0-9][^-]*-x86_64\\.AppImage$"))] | first // empty' <<<"$rel")"
[ -n "$asset" ] || { echo "no x86_64 AppImage in release $version" >&2; exit 1; }
name="$(jq -r '.name' <<<"$asset")"
url="$(jq -r '.browser_download_url' <<<"$asset")"
size="$(jq -r '.size' <<<"$asset")"
sum_url="$(jq -r --arg n "$name.sha256" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel")"
[ -n "$sum_url" ] || { echo "no $name.sha256 in release $version" >&2; exit 1; }
sha256="$(curl -fsSL "$sum_url" | awk '{print $1}' | head -n1)"

[ -n "$version" ] && [ "$version" != "null" ] || { echo "failed to resolve dinox release" >&2; exit 1; }
printf '%s' "$sha256" | grep -Eq '^[0-9a-f]{64}$' || { echo "bad sha256 in $sum_url: $sha256" >&2; exit 1; }
case "$size" in ''|*[!0-9]*) echo "bad size for $name: $size" >&2; exit 1 ;; esac
echo "resolved dinox $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg s "$sha256" --argjson z "$size" \
  '{version:$v, releaseDate:$d, sources:[{filename:"dinox.AppImage", url:$u, size:$z, sha256:$s}]}'
