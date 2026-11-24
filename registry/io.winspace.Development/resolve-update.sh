#!/usr/bin/env bash
# Update resolver for OpenXplorer.
#
# Prints the latest release and its Debian package as JSON on stdout; logs go
# to stderr. The package is the release's one `openxplorer_<version>_all.deb`
# asset (labelled `all`, it holds the x86_64 build); the release also carries
# a .flatpak bundle, .rpm and Arch packages, the source and SHA256SUMS.
set -euo pipefail

repo="AKolenda/openxplorer"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r --arg v "$version" \
        '.assets[] | select(.name == ("openxplorer_" + $v + "_all.deb")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] && [ "$(wc -l <<<"$url")" -eq 1 ] \
  || { echo "failed to resolve the OpenXplorer release" >&2; exit 1; }
echo "resolved openxplorer $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"openxplorer.deb", url:$u}]}'
