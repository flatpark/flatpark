#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/chiriapp/chiri/releases/latest)"
# app-v is upstream's stable application release tag prefix.
jq -e '
  (.tag_name | capture("^app-v(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)$").version) as $v |
  [.assets[] | select(.name == ("Chiri_" + $v + "_amd64.deb"))] as $x |
  [.assets[] | select(.name == ("Chiri_" + $v + "_arm64.deb"))] as $a |
  if ($x | length) != 1 or ($a | length) != 1 then error("expected one Debian asset per architecture") else
  {version:$v, releaseDate:(.published_at[0:10]), releaseUrl:.html_url,
   sources:[{filename:"chiri.deb", arch:"x86_64", url:$x[0].browser_download_url},
            {filename:"chiri.deb", arch:"aarch64", url:$a[0].browser_download_url}]} end
' <<<"$rel"
