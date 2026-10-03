#!/usr/bin/env bash
# Update resolver for Altair GraphQL Client.
#
# Prints the latest version, release date and the official Linux x86_64 .deb as
# JSON on stdout; logs go to stderr. Hashing and manifest rewriting are handled
# by FlatPark's update automation.
#
# The asset is matched on the amd64 .deb suffix only, never assembled from the
# tag. The release also ships arm64 builds, AppImages, a snap and macOS/Windows
# installers, so an ambiguous match is an error rather than a silent
# first-match.
set -euo pipefail

repo="altair-graphql/altair"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("_amd64_linux\\.deb$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Altair GraphQL Client release" >&2
  exit 1
}
echo "resolved Altair GraphQL Client $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.deb", url:$u}]}'
