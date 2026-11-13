#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    https://api.github.com/repos/TagStudioDev/TagStudio/releases/latest)"
# Match the regular directory build exactly, excluding the one-file portable
# build and releases for other operating systems or architectures.
jq -e '
  (.tag_name | ltrimstr("v")) as $version |
  [.assets[] | select(.name == "tagstudio_v\($version)_linux_x86_64.tar.gz")] as $assets |
  if ($version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
     (.published_at | type == "string") and ($assets | length == 1) and
     ($assets[0].browser_download_url | startswith("https://github.com/TagStudioDev/TagStudio/releases/download/"))
  then {version: $version, releaseDate: (.published_at[0:10]),
        sources: [{filename: "tagstudio.tar.gz", url: $assets[0].browser_download_url, arch: "x86_64"}]}
  else error("expected a release with exactly one official Linux x86_64 directory archive") end
' <<<"$rel"
