#!/usr/bin/env bash
set -euo pipefail
# Resolve both official portable builds; never guess an asset URL.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    https://api.github.com/repos/tagspaces/tagspaces/releases/latest)"
jq -e '
  (.tag_name | ltrimstr("v")) as $v |
  [.assets[] | select(.name == ("tagspaces-linux-x64-" + $v + ".tar.gz"))] as $x |
  [.assets[] | select(.name == ("tagspaces-linux-arm64-" + $v + ".tar.gz"))] as $a |
  if ($x|length) != 1 or ($a|length) != 1 then error("expected one tarball per architecture")
  else {version:$v, releaseDate:(.published_at[:10]), sources:[
    {filename:"tagspaces.tar.gz", arch:"x86_64", url:$x[0].browser_download_url},
    {filename:"tagspaces.tar.gz", arch:"aarch64", url:$a[0].browser_download_url}
  ]} end' <<<"$rel"
