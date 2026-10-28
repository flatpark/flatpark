#!/usr/bin/env bash
set -euo pipefail
repo=Universal-Debloater-Alliance/universal-android-debloater-next-generation
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"}     "https://api.github.com/repos/$repo/releases/latest")"
jq -e '
  [.assets[] | select(.name == "uad-ng-noselfupdate-linux.tar.gz")] as $assets |
  if ($assets | length) != 1 then error("expected one Linux tarball without self-updates")
  else {
    version: (.tag_name | ltrimstr("v")),
    releaseDate: (.published_at | split("T")[0]),
    sources: [{filename: "uad-ng.tar.gz", url: $assets[0].browser_download_url, arch: "x86_64"}]
  } end' <<<"$rel"
