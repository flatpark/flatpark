#!/usr/bin/env bash
set -euo pipefail
# Pin the official Ubuntu x86_64 portable build, never a prerelease or installer.
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    https://api.github.com/repos/NatLabRockies/EnergyPlus/releases/latest)"
jq -e '
  [.assets[] | select(.name | test("^EnergyPlus-[0-9]+\\.[0-9]+\\.[0-9]+-[0-9a-f]+-Linux-Ubuntu24\\.04-x86_64\\.tar\\.gz$"))] as $assets |
  if (.draft or .prerelease or ($assets | length) != 1) then
    error("expected one stable Ubuntu 24.04 x86_64 tarball")
  else {
    version: (.tag_name | ltrimstr("v")),
    releaseDate: (.published_at[0:10]),
    sources: [{filename: "energyplus.tar.gz", url: $assets[0].browser_download_url, arch: "x86_64"}]
  } end' <<<"$release"
