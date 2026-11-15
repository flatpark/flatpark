#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    https://api.github.com/repos/LostRuins/koboldcpp/releases/latest)"
# Exact names keep oldpc, Windows and the other Linux edition out of this package.
jq -e --arg asset "koboldcpp-linux-x64-nocuda" '
    [.assets[] | select(.name == $asset)] as $assets
    | if .draft or .prerelease or ($assets | length) != 1 then
        error("expected exactly one stable Linux asset")
      else
        {version: (.tag_name | ltrimstr("v")), releaseDate: .published_at[0:10],
         sources: [{filename: "koboldcpp.bin", arch: "x86_64", url: $assets[0].browser_download_url}]}
      end' <<<"$release"
