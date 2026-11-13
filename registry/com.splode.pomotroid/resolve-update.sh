#!/usr/bin/env bash
# Resolve the official x86_64 Debian release; stdout is updater JSON only.
set -euo pipefail
headers=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
rel=$(curl -fsSL "${headers[@]}" https://api.github.com/repos/Splode/pomotroid/releases/latest)
jq -e '
  [.assets[] | select(.name | test("_amd64\\.deb$"))] as $assets |
  if ($assets | length) != 1 then error("expected one amd64 Debian asset") else
    {version: (.tag_name | ltrimstr("v")), releaseDate: (.published_at[0:10]),
     sources: [{filename: "pomotroid.deb", url: $assets[0].browser_download_url}]}
  end
' <<<"$rel"
