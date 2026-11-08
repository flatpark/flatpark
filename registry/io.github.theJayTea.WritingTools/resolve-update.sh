#!/usr/bin/env bash
set -euo pipefail
headers=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
release=$(curl -fsSL "${headers[@]}" https://api.github.com/repos/rhgKc2yp/writingtools-release/releases/latest)
jq -e '
  [.assets[] | select(.name == "writing-tools-fedora45-x86_64.tar.gz")] as $assets |
  if .draft or .prerelease or ($assets | length) != 1 or .published_at == null then
    error("Expected one published Linux payload")
  else {
    version: (.tag_name | ltrimstr("v")),
    releaseDate: (.published_at | split("T")[0]),
    sources: [{filename: "writing-tools.tar.gz", url: $assets[0].browser_download_url}]
  } end' <<< "$release"
