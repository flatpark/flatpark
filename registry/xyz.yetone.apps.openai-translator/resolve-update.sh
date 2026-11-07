#!/usr/bin/env bash
# Resolve only the official stable Linux Debian asset; diagnostics go to stderr.
set -euo pipefail
repo=nextai-translator/nextai-translator
headers=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
release=$(curl -fsSL "${headers[@]}" "https://api.github.com/repos/$repo/releases/latest")
jq -e '
  [.assets[] | select(.name | test("_amd64\\.deb$"))] as $assets |
  if ($assets | length) != 1 or (.tag_name | type) != "string" or
     (.published_at | type) != "string" then error("expected one Linux Debian release")
  else {
    version: (.tag_name | ltrimstr("v")),
    releaseDate: (.published_at[0:10]),
    sources: [{filename: "nextai.deb", url: $assets[0].browser_download_url}]
  } end
' <<< "$release"
