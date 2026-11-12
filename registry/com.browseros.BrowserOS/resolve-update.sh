#!/usr/bin/env bash
set -euo pipefail
# This repository also publishes extension/server releases. Select the newest
# browser asset by its full numeric version, rather than trusting the tag name.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  'https://api.github.com/repos/browseros-ai/BrowserOS/releases?per_page=100')"
jq -e '
  [ .[] | select(.draft == false and .prerelease == false) as $r
    | $r.assets[]
    | select(.name | test("^BrowserOS_neo_v[0-9]+(\\.[0-9]+)+_amd64\\.deb$"))
    | {version: (.name | capture("^BrowserOS_neo_v(?<v>.+)_amd64\\.deb$").v),
       releaseDate: ($r.published_at[0:10]),
       sources: [{filename: "browseros.deb", url: .browser_download_url, arch: "x86_64"}]} ]
  | sort_by(.version | split(".") | map(tonumber)) | last
  | select(.version != null and (.sources | length) == 1)
' <<<"$rel"
