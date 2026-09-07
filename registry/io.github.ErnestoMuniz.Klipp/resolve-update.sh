#!/usr/bin/env bash
# Update resolver for Klipp.
#
# Prints the latest version, release date and official Linux x86_64 tarball
# as JSON on stdout. Logs go to stderr; hashing and manifest updates are
# handled by FlatPark's update automation.
set -euo pipefail

repo="ErnestoMuniz/klipp"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Upstream publishes one tarball per arch; match the x86_64 Linux payload
# exactly so a renamed asset cannot be picked up by accident.
url="$(jq -r '.assets[] | select(.name | test("^klipp-.*-linux-x86_64\\.tar\\.gz$")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Klipp release" >&2
  exit 1
}
echo "resolved Klipp $version ($date): $url" >&2

filename="$(basename "$url")"
jq -n --arg v "$version" --arg d "$date" --arg f "$filename" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:$f, url:$u}]}'
