#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest)"
# Match only the official glibc onedir builds, whose self-updater is disabled.
jq -e '
  def asset($name):
    [.assets[] | select(.name == $name)]
    | if length == 1 then .[0] else error("expected exactly one " + $name) end;
  . as $r | ($r | asset("yt-dlp_linux.zip")) as $x
  | ($r | asset("yt-dlp_linux_aarch64.zip")) as $a
  | {version: .tag_name, releaseDate: .published_at[0:10],
     sources: [{filename: "yt-dlp.zip", arch: "x86_64", url: $x.browser_download_url},
               {filename: "yt-dlp.zip", arch: "aarch64", url: $a.browser_download_url}]}
' <<<"$release"
