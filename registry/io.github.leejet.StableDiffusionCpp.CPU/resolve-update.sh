#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/leejet/stable-diffusion.cpp/releases/latest)"
# Match the backend exactly; Ubuntu release and abbreviated commit may change.
jq -e '
  [.assets[] | select(.name | test("^sd-master-[0-9a-f]+-bin-Linux-Ubuntu-[0-9]+\\.[0-9]+-x86_64\\.zip$"))] as $assets
  | if ($assets | length) != 1 then error("expected exactly one Linux CPU x86_64 archive") else
    {version: .tag_name, releaseDate: .published_at[0:10],
     sources: [{filename: "sd.zip", arch: "x86_64", url: $assets[0].browser_download_url}]}
    end' <<<"$release"
