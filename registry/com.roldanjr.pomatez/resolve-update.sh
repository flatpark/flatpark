#!/usr/bin/env bash
set -euo pipefail
# Stable Electron releases only; exclude the Tauri beta assets in the same release.
headers=()
[ -z "${GITHUB_TOKEN:-}" ] || headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
rel="$(curl -fsSL "${headers[@]}" https://api.github.com/repos/zidoro/pomatez/releases/latest)"
jq -e '
  .tag_name as $tag |
  [.assets[] | select(.name == ("Pomatez-" + $tag + "-linux-x86_64.AppImage"))] as $assets |
  if ($assets | length) != 1 or (.published_at | type) != "string" then
    error("expected exactly one stable Linux x86_64 Electron AppImage")
  else {
    version: ($tag | ltrimstr("v")),
    releaseDate: (.published_at[0:10]),
    sources: [{filename: "pomatez.AppImage", url: $assets[0].browser_download_url}]
  } end
' <<<"$rel"
