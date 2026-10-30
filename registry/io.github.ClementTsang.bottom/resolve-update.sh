#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/ClementTsang/bottom/releases/latest)"
# Select upstream's standard x86_64 glibc build, which supports dynamic
# loading of host driver libraries such as NVIDIA's NVML.
jq -e '
  [.assets[] | select(.name == "bottom_x86_64-unknown-linux-gnu.tar.gz")] as $assets
  | if ($assets | length) != 1 then error("expected one standard x86_64 glibc asset") else
    {version: (.tag_name | ltrimstr("v")), releaseDate: (.published_at[0:10]),
     sources: [{filename: "bottom.tar.gz", arch: "x86_64", url: $assets[0].browser_download_url}]}
    end' <<<"$release"
