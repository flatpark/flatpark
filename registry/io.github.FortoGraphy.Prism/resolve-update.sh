#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/FortoGraphy/prism-download-manager/releases/latest)"
jq -e '{version:(.tag_name | ltrimstr("v")), releaseDate:(.published_at[0:10]), sources:[.assets[] | select(.name | test("^Prism_.*_amd64\\.deb$")) | {filename:"prism.deb", url:.browser_download_url}]} | select(.version != "" and (.sources | length == 1))' <<<"$rel"
