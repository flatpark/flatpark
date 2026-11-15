#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/ollama/ollama/releases/latest)"
jq -e '
  [.assets[] | select(.name == "ollama-linux-amd64.tar.zst")] as $assets
  | if ($assets | length) != 1 then error("expected exactly one Linux amd64 asset") else
    {version: (.tag_name | ltrimstr("v")), releaseDate: .published_at[0:10],
     sources: [{filename: "ollama.tar.zst", arch: "x86_64", url: $assets[0].browser_download_url}]}
    end' <<<"$release"
