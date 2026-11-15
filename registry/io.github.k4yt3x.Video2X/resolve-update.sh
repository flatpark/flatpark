#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/k4yt3x/video2x/releases/latest)"
# The official Linux release is a CLI AppImage, distinct from the Windows GUI.
jq -e '
  [.assets[] | select(.name == "Video2X-x86_64.AppImage")] as $assets |
  if ($assets | length) != 1 then error("expected one Linux x86_64 AppImage")
  else {
    version: (.tag_name | ltrimstr("v")),
    releaseDate: (.published_at | .[0:10]),
    sources: [{filename: "video2x.AppImage", arch: "x86_64", url: $assets[0].browser_download_url}]
  } end' <<<"$rel"
