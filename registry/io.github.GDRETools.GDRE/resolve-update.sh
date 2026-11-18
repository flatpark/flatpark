#!/usr/bin/env bash
# Update resolver for Godot RE Tools: the latest stable GitHub release and its
# official Linux zip. Prints { "version", "releaseDate", "sources": [...] } on
# stdout; logs go to stderr. FlatPark downloads the URL and computes the
# sha256/size itself.
set -euo pipefail

repo="GDRETools/gdsdecomp"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | sub("^v";"")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Anchor the name: the release also carries android, macOS and Windows zips,
# and the Linux one is GDRE_tools-v<version>-linux.zip.
url="$(jq -r --arg name "GDRE_tools-v${version}-linux.zip" \
        '.assets[] | select(.name == $name) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve gdsdecomp release" >&2; exit 1; }
echo "resolved gdsdecomp $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"gdre_tools.zip", url:$u}]}'
