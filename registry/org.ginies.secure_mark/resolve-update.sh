#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/aginies/SecureMark/releases/latest)"
jq -e '
  (.assets | map(select(.name | test("^SecureMark-v[^/]+-Linux\\.AppImage$")))) as $assets |
  if ($assets | length) != 1 then error("expected exactly one Linux AppImage") else
    {version: (.tag_name | sub("^v"; "")), releaseDate: (.published_at[:10]),
     sources: [{filename: "securemark.AppImage", url: $assets[0].browser_download_url}]}
  end' <<<"$release"
