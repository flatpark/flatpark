#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/audacity/audacity/releases/latest)"
jq -e '
  . as $release |
  (.tag_name | capture("^Audacity-(?<v>[0-9]+\\.[0-9]+\\.[0-9]+)$").v) as $version |
  [.assets[] | select(.name == ("audacity-linux-" + $version + "-x86_64.AppImage"))] as $assets |
  if ($assets | length) != 1 then error("expected one official x86_64 AppImage") else
  {version:$version, releaseDate:($release.published_at[0:10]), releaseUrl:$release.html_url,
   sources:[{filename:"audacity.AppImage", arch:"x86_64", url:$assets[0].browser_download_url}]}
  end' <<<"$rel"
