#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/nyosegawa/speech.cpp/releases/latest)"
jq -e '
  . as $r | [.assets[] | select(.name == ("speech-" + ($r.tag_name | ltrimstr("v")) + "-linux-x64-vulkan.zip"))] as $assets
  | if ($assets | length) != 1 then error("expected one vulkan Linux release asset") else
    {version: (.tag_name | ltrimstr("v")), releaseDate: .published_at[0:10],
      sources: [{filename: "speech.zip", arch: "x86_64", url: $assets[0].browser_download_url}]}
    end' <<<"$release"
