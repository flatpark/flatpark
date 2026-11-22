#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/schollz/croc/releases/latest)"
jq -e '
  .tag_name as $tag
  | [.assets[] | select(.name == ("croc_" + $tag + "_Linux-64bit.tar.gz"))] as $x
  | [.assets[] | select(.name == ("croc_" + $tag + "_Linux-ARM64.tar.gz"))] as $a
  | if ($x | length) != 1 or ($a | length) != 1 then error("expected one archive per architecture") else
    {version: ($tag | ltrimstr("v")), releaseDate: .published_at[0:10], sources: [
      {filename: "croc.tar.gz", arch: "x86_64", url: $x[0].browser_download_url},
      {filename: "croc.tar.gz", arch: "aarch64", url: $a[0].browser_download_url}]}
    end' <<<"$release"
