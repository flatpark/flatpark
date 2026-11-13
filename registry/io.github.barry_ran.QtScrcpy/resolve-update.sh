#!/usr/bin/env bash
set -euo pipefail
# Match only the official x86_64 Linux AppImage; other platforms and server-only
# releases must never become this package's payload.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    https://api.github.com/repos/barry-ran/QtScrcpy/releases/latest)"
jq -e '
  . as $r
  | ($r.tag_name | ltrimstr("v")) as $v
  | [$r.assets[] | select(.name == ("QtScrcpy-ubuntu-x64-v" + $v + ".AppImage"))] as $a
  | if ($v | length) == 0 or ($a | length) != 1 then
      error("expected exactly one official Linux x86_64 release asset")
    else {
      version: $v,
      releaseDate: ($r.published_at[0:10]),
      releaseUrl: $r.html_url,
      sources: [{filename: "qtscrcpy.AppImage", arch: "x86_64", url: $a[0].browser_download_url}]
    } end
' <<<"$rel"
