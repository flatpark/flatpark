#!/usr/bin/env bash
# Update resolver for Termix.
#
# Prints the latest version, release date and the official Linux x86_64 .deb as
# JSON on stdout; logs go to stderr. Hashing and manifest rewriting are handled
# by FlatPark's update automation.
#
# Releases are tagged release-<version>-tag. The .deb carries no version in its
# name (termix_linux_x64_deb.deb), so it is matched on that exact name; the same
# release also ships an AppImage, a portable tarball, a .flatpak bundle and the
# arm64/macOS/Windows builds. An ambiguous match is an error rather than a
# silent first-match.
set -euo pipefail

repo="Termix-SSH/Termix"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("release-") | rtrimstr("-tag") | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name == "termix_linux_x64_deb.deb") | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || {
  echo "unexpected Termix tag: $(jq -r .tag_name <<<"$rel")" >&2
  exit 1
}
[ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Termix release" >&2
  exit 1
}
echo "resolved Termix $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.deb", url:$u}]}'
