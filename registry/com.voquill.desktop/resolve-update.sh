#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/voquill/voquill/releases/latest)"
jq -e '
  [.assets[] | select(.name | test("^voquill-desktop_[0-9.]+_amd64\\.deb$"))] as $assets
  | if (.draft or .prerelease or ($assets | length) != 1 or (.tag_name | test("^desktop-v[0-9]+(\\.[0-9]+)+$") | not))
    then error("expected one stable Voquill amd64 Debian artifact")
    else {version:(.tag_name | ltrimstr("desktop-v")), releaseDate:(.published_at[:10]),
          sources:[{filename:"voquill.deb", url:$assets[0].browser_download_url, arch:"x86_64"}]} end
' <<<"$rel"
