#!/usr/bin/env bash
set -euo pipefail
# Only stable upstream releases. Match the x86_64 asset exactly to exclude ARM64.
# `size` lets update-pins re-pin when upstream replaces the asset under the same
# tag (v4.3.3 was re-uploaded on 2026-10-29, #895).
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    https://api.github.com/repos/Autonomy-Logic/openplc-editor/releases/latest)"
jq -e '
  .tag_name as $tag |
  ($tag | ltrimstr("v")) as $version |
  [.assets[] | select(.name == ("OpenPLC.Editor-" + $version + ".AppImage"))] as $assets |
  if ($version | length) > 0 and ($assets | length) == 1 then
    {version: $version, releaseDate: (.published_at[0:10]),
     sources: [{filename: "openplc.AppImage", url: $assets[0].browser_download_url,
                size: $assets[0].size}]}
  else error("expected exactly one stable x86_64 OpenPLC AppImage") end
' <<<"$rel"
