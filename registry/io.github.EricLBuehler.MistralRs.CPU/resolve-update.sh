#!/usr/bin/env bash
set -euo pipefail
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/EricLBuehler/mistral.rs/releases/latest)"
jq -e '
  . as $r
  | [.assets[] | select(.name == "mistralrs-cpu-x86_64-unknown-linux-gnu.tar.gz")] as $assets
  | if ($assets | length) != 1 then error("expected exactly one Linux x86_64 CPU asset") else $assets[0] end as $asset
  | {version: (.tag_name | ltrimstr("v")),
     releaseDate: $r.published_at[0:10],
     sources: [{filename: "mistralrs.tar.gz", arch: "x86_64", url: $asset.browser_download_url}]}
' <<<"$release"
