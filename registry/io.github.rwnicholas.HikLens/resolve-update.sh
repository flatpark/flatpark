#!/usr/bin/env bash
# Update resolver for HikLens: the latest GitHub release and its x86_64 AppImage.
# Prints { "version", "releaseDate", "sources": [...] } on stdout; logs go to
# stderr. update-pins reads the GitHub release asset's digest and size.
set -euo pipefail

repo="rwnicholas/HikLens"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

jq -e '
  (.tag_name | ltrimstr("v")) as $version |
  ([.assets[] | select(.name == ("HikLens-v" + $version + "-x86_64.AppImage"))] |
    if length == 1 then .[0].browser_download_url
    else error("failed to resolve HikLens release: no x86_64 AppImage for " + $version) end) as $url |
  {version: $version, releaseDate: (.published_at | split("T")[0]),
   sources: [{filename: "hiklens.AppImage", url: $url}]} |
  if (.version | length) > 0 and (.releaseDate | length) > 0 then . else error("missing release metadata") end
' <<<"$rel"
