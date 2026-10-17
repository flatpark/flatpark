#!/usr/bin/env bash
# Update resolver for v2rayN.
#
# Prints the latest version, release date and the official Linux x64 .deb as
# JSON on stdout; logs go to stderr. FlatPark downloads the URL and computes
# the extra-data sha256/size itself.
#
# Each release carries .deb/.rpm/.zip builds for several arches plus a .sig for
# each; the asset name has no version in it, so it is matched exactly.
set -euo pipefail

repo="2dust/v2rayN"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name == "v2rayN-linux-64.deb") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || { echo "failed to resolve v2rayN release" >&2; exit 1; }
[ "$(wc -l <<<"$url")" -eq 1 ] || { echo "expected exactly one v2rayN-linux-64.deb, got:" >&2; echo "$url" >&2; exit 1; }
echo "resolved v2rayN $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.deb", arch:"x86_64", url:$u}]}'
