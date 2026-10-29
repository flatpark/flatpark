#!/usr/bin/env bash
# Follow official stable desktop releases; stdout is only the updater JSON.
set -euo pipefail
headers=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
curl -fsSL --retry 3 "${headers[@]}" \
    https://api.github.com/repos/Mintplex-Labs/anything-llm/releases/latest |
jq -e '
  . as $release |
  [.assets[] | select(.name == "AnythingLLMDesktop.AppImage")] as $assets |
  if ($assets | length) != 1 then error("expected one x86_64 desktop AppImage")
  else {
    version: ($release.tag_name | ltrimstr("v")),
    releaseDate: ($release.published_at | split("T")[0]),
    sources: [{filename: "anythingllm.AppImage", url: $assets[0].browser_download_url, arch: "x86_64"}]
  } end'
