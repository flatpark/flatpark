#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/ip7z/7zip/releases/latest)"
# Match only the official 64-bit Linux console archives, never Windows,
# macOS, source, or 32-bit artifacts. Require both architectures per release.
jq -e '
  . as $release
  | (.tag_name | ltrimstr("v")) as $version
  | ($version | gsub("\\."; "")) as $stem
  | [ {arch: "x86_64", suffix: "x64"}, {arch: "aarch64", suffix: "arm64"} ]
  | map(. as $target
      | [$release.assets[] | select(.name == ("7z" + $stem + "-linux-" + $target.suffix + ".tar.xz"))] as $assets
      | if ($assets | length) != 1 then error("expected one Linux console asset for " + $target.arch)
        else {filename: "sevenzip.tar.xz", arch: $target.arch, url: $assets[0].browser_download_url}
        end)
  | {version: $version, releaseDate: ($release.published_at[0:10]), sources: .}
' <<<"$release"
