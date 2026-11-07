#!/usr/bin/env bash
set -euo pipefail
# Only official stable releases; logs on stderr, resolver JSON on stdout.
headers=()
[ -z "${GITHUB_TOKEN:-}" ] || headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
release=$(curl -fsSL "${headers[@]}" https://api.github.com/repos/mdSilo/mdSilo-app/releases/latest)
jq -e '
  (.tag_name | capture("^(mdsilo-)?v?(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)$").version) as $version
  | [.assets[] | select(.name | test("_amd64\\.deb$"))] as $assets
  | if ($assets | length) != 1 then error("expected exactly one Linux amd64 deb")
    else {version: $version, releaseDate: (.published_at[0:10]),
      sources: [{filename: "mdsilo.deb", url: $assets[0].browser_download_url}]} end
' <<<"$release"
