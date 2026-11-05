#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/ElCruncharino/neostego/releases/latest)"
jq -e '
  [.assets[] | select(.name | test("^neostego_[0-9][0-9A-Za-z.+~-]*_amd64\\.deb$"))] as $assets |
  if ($assets | length) != 1 then error("expected one Linux amd64 Debian release") else
  {version: (.tag_name | ltrimstr("v")), releaseDate: (.published_at | split("T")[0]),
   sources: [{filename: "neostego.deb", arch: "x86_64", url: $assets[0].browser_download_url}]}
  end' <<<"$rel"
