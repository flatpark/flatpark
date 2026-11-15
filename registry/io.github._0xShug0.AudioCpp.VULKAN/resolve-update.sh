#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/0xShug0/audio.cpp/releases/latest)"
jq -e '
  . as $r | [.assets[] | select(.name == ("audio-" + $r.tag_name + "-bin-ubuntu-x64-vulkan-portable.tar.gz"))] as $assets
  | if ($assets | length) != 1 then error("expected one vulkan portable Linux asset") else
    {version: (.tag_name | ltrimstr("v")), releaseDate: .published_at[0:10],
      sources: [{filename: "audio.tar.gz", arch: "x86_64", url: $assets[0].browser_download_url}]}
    end' <<<"$release"
