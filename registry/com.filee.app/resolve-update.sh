#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/KnifeLemon/Filee/releases/latest)"
# Only the official x64 portable Linux archive, never checksums or other OSes.
jq -e '
  (.tag_name | ltrimstr("v")) as $v |
  [.assets[] | select(.name == "Filee-" + $v + "-linux-x64.tar.gz")] as $a |
  if ($a | length) != 1 or ($v | length) == 0 then
    error("expected exactly one Filee Linux x64 portable archive")
  else {version:$v, releaseDate:(.published_at[:10]),
    sources:[{filename:"filee.tar.gz", url:$a[0].browser_download_url, size:$a[0].size}]}
  end' <<<"$rel"
