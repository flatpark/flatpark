#!/usr/bin/env bash
# Latest GitHub release; the Ubuntu 26.04 .deb is the build that matches the
# GNOME 51 runtime's libraries.
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/zackb/tether/releases/latest)"
jq -e '
  (.tag_name | ltrimstr("v")) as $version |
  [.assets[] | select(.name == ("tether_" + $version + "_amd64.ubuntu26.04.deb"))] as $deb |
  if ($deb | length) != 1 then error("expected one amd64 ubuntu26.04 .deb for " + $version) else . end |
  {version: $version, releaseDate: (.published_at | split("T")[0]),
   releaseUrl: .html_url,
   sources: [{filename: "tether.deb", url: $deb[0].browser_download_url, arch: "x86_64"}]} |
  if (.version | length) > 0 then . else error("missing version") end
' <<< "$release"
