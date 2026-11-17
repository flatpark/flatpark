#!/usr/bin/env bash
set -euo pipefail
headers=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
curl -fsSL --retry 3 "${headers[@]}" \
    https://api.github.com/repos/Chipi-Chapa-Corp/papers/releases/latest |
    jq -e '
      (.tag_name | ltrimstr("v")) as $version |
      [.assets[] | select(.name == "dokument-linux-x86_64.tar.gz") | .browser_download_url] as $urls |
      if ($version | test("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$")) and ($urls | length) == 1 then
        {version: $version, releaseDate: (.published_at | split("T")[0]),
         sources: [{filename: "dokument.tar.gz", arch: "x86_64", url: $urls[0]}]}
      else error("Expected exactly one official stable dokument-linux-x86_64.tar.gz") end'
