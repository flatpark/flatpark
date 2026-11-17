#!/usr/bin/env bash
set -euo pipefail
# This prebuilt is tied to GNOME 51. A new stack major needs a reviewed runtime pin.
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/flatpark/prebuilt/releases/tags/ffmpeg-full-v3)"
jq -e '
  [.assets[] | select(.name == "ffmpeg-full-ffmpeg-full-v3-gnome-51-x86_64.tar.xz")] as $a
  | if ($a | length) != 1 then error("expected one ffmpeg-full asset") else . end
  | {version: .tag_name, releaseDate: .published_at[0:10], sources: [{filename: "ffmpeg-full.tar.xz", arch: "x86_64", url: $a[0].browser_download_url}]}
' <<<"$release"
