#!/usr/bin/env bash
# Update resolver for Tavern: the latest GitHub release and its AppImage.
# Prints { "version", "releaseDate", "sources": [...] } on stdout; logs go to
# stderr. FlatPark downloads the URL and computes the sha256/size itself.
set -euo pipefail

repo="tuna-os/Tavern"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | sub("^v";"")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name == "Tavern-Linux.AppImage") | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve tavern release" >&2; exit 1; }
echo "resolved tavern $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"tavern.AppImage", url:$u}]}'
