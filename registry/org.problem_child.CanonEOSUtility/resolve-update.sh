#!/usr/bin/env bash
# FlatPark update resolver: prints the current release version and its download.
#
# FlatPark runs this daily; when the version differs from the latest <release>
# in the metainfo it downloads the source, re-pins it and opens a PR.
set -euo pipefail

repo="night199uk/canon-eos-utility-linux"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r --arg name "canon-eos-utility-${version}-x86_64.tar.xz" \
        '.assets[] | select(.name == $name) | .browser_download_url' <<<"$rel")"

[ -n "$url" ] || { echo "no canon-eos-utility tarball asset on release $version" >&2; exit 1; }

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"canon-eos-utility.tar.xz", url:$u}]}'
