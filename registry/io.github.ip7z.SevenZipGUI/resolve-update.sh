#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/ip7z/7zip/releases/latest)"
jq -e '
  . as $release | (.tag_name | ltrimstr("v")) as $version
  | ($version | gsub("\\."; "")) as $stem
  | [$release.assets[] | select(.name == ("7z" + $stem + "-x64.exe"))] as $assets
  | if ($assets | length) != 1 then error("expected one Windows x64 installer")
    else {version: $version, releaseDate: ($release.published_at[0:10]), sources: [{filename: "7zip.exe", arch: "x86_64", url: $assets[0].browser_download_url}]} end
' <<<"$release"
