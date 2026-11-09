#!/usr/bin/env bash
# Update resolver for the Horizon launcher.
#
# Prints the latest launcher release and its Linux x86_64 tarball as JSON on
# stdout; logs go to stderr. The repository publishes two release series: the
# game (`v0.2.97`), which is what /releases/latest returns, and the launcher
# (`launcher@0.2.56`), which is what this package installs. The launcher
# downloads game builds by itself, so only the `launcher@` series is followed.
set -euo pipefail

repo="horizon-rust/horizon"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=50")"

rel="$(jq -c '[.[] | select(.draft == false and .prerelease == false
                           and (.tag_name | startswith("launcher@")))] | first // empty' <<<"$rels")"
[ -n "$rel" ] || { echo "no launcher@ release in the latest 50" >&2; exit 1; }

version="$(jq -r '.tag_name | ltrimstr("launcher@")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Anchored: the release also carries the AppImage and the macOS/Windows builds.
url="$(jq -r '.assets[] | select(.name == "horizon-launcher-linux-x86_64.tar.gz") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve horizon launcher release" >&2; exit 1; }
echo "resolved horizon launcher $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"horizon-launcher.tar.gz", url:$u}]}'
