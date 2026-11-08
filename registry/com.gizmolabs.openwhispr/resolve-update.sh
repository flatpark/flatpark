#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  https://api.github.com/repos/OpenWhispr/openwhispr/releases/latest)"
# Reject unexpected versions and missing or ambiguous artifacts; never return a partial release.
jq -e '
  [.assets[] | select(.name | test("-linux-x64\\.tar\\.gz$"))] as $assets |
  (.tag_name | ltrimstr("v")) as $version |
  if ($assets | length) != 1 or ($version | test("^[0-9]+(\\.[0-9]+)+$") | not) or .published_at == null
  then error("expected a stable numeric version with one Linux x64 tarball")
  else {version:$version, releaseDate:(.published_at[:10]),
    sources:[{filename:"openwhispr.tar.gz", arch:"x86_64", url:$assets[0].browser_download_url}]}
  end' <<<"$rel"
