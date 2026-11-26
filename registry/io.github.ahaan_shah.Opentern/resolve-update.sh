#!/usr/bin/env bash
set -euo pipefail
rel=$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/ahaan-shah/opentern/releases/latest)
version=$(jq -er '.tag_name | select(test("^v?[0-9]")) | ltrimstr("v")' <<<"$rel")
date=$(jq -er '.published_at | .[0:10]' <<<"$rel")
asset() {
  jq -er --arg name "$1" '[.assets[] | select(.name == $name) | .browser_download_url] | if length == 1 then .[0] else error("expected one matching asset") end' <<<"$rel"
}
x=$(asset opentern-x86_64-unknown-linux-gnu.tar.gz)
a=$(asset opentern-aarch64-unknown-linux-gnu.tar.gz)
jq -n --arg v "$version" --arg d "$date" --arg x "$x" --arg a "$a" '{version:$v,releaseDate:$d,sources:[{filename:"opentern-x86_64.tar.gz",url:$x},{filename:"opentern-aarch64.tar.gz",url:$a}]}'
