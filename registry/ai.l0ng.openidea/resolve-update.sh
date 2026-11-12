#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/l0ng-ai/openidea/releases/latest)"
jq -e '
  (.tag_name | ltrimstr("v")) as $version |
  def asset($arch):
    [.assets[] | select(.name == ("OpenIDEA_" + $version + "_" + $arch + ".deb"))] |
    if length == 1 then .[0].browser_download_url else error("expected one Debian asset for " + $arch) end;
  {version: $version, releaseDate: (.published_at | split("T")[0]),
   sources: [{filename: "openidea.deb", url: asset("amd64"), arch: "x86_64"},
             {filename: "openidea.deb", url: asset("arm64"), arch: "aarch64"}]} |
  if (.version | length) > 0 and (.releaseDate | length) > 0 then . else error("missing release metadata") end
' <<< "$release"
