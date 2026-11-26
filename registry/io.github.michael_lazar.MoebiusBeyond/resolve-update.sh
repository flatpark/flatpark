#!/usr/bin/env bash
set -euo pipefail
rel=$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/michael-lazar/moebius-beyond/releases/latest)
jq -e '
  (.tag_name | ltrimstr("v")) as $version |
  (.published_at[0:10]) as $date |
  [.assets[] | select(.name == "MoebiusBeyond-amd64.deb" or .name == "MoebiusBeyond-arm64.deb") |
    {filename:"moebius.deb", arch:(if .name == "MoebiusBeyond-amd64.deb" then "x86_64" else "aarch64" end), url:.browser_download_url}] as $sources |
  if ($version != "" and ($sources | length) == 2) then {version:$version, releaseDate:$date, sources:$sources} else error("missing release or architecture") end
' <<< "$rel"
