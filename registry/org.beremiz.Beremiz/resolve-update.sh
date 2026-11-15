#!/usr/bin/env bash
set -euo pipefail
# Follow the public community build repository, separately from upstream Snap releases.
repo=rhgKc2yp/beremiz-release
headers=()
[ -z "${GITHUB_TOKEN:-}" ] || headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
release=$(curl -fsSL "${headers[@]}" "https://api.github.com/repos/$repo/releases/latest")
# Keep the rebuild revision: 1.6.0-2 must update a 1.6.0-1 install.
jq -e '
  select(.draft == false and .prerelease == false) |
  . as $r |
  ($r.tag_name | ltrimstr("v")) as $version |
  [ ["x86_64", "aarch64"][] as $arch |
    [ $r.assets[] | select(.name == ("beremiz-" + $version + "-" + $arch + ".tar.gz")) ] as $assets |
    if ($assets | length) != 1 then error("Missing or ambiguous " + $arch + " Beremiz archive")
    else {filename: "beremiz.tar.gz", arch: $arch, url: $assets[0].browser_download_url, size: $assets[0].size}
    end
  ] as $sources |
  {
    version: $version,
    releaseDate: ($r.published_at[0:10]),
    releaseUrl: $r.html_url,
    sources: $sources
  }
' <<< "$release"
