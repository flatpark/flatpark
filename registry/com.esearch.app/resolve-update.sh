#!/usr/bin/env bash
set -euo pipefail
# Resolve official stable releases; stdout is exclusively the updater JSON.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/xushengfeng/eSearch/releases/latest)"
jq -e '
  def asset($arch): [.assets[] | select(.name | endswith("-linux-" + $arch + ".tar.gz"))] |
    if length == 1 then .[0].browser_download_url else error("expected one tarball for " + $arch) end;
  {version: (.tag_name | ltrimstr("v")), releaseDate: (.published_at[0:10]),
   sources: [{filename: "esearch.tar.gz", arch: "x86_64", url: asset("x64")},
             {filename: "esearch.tar.gz", arch: "aarch64", url: asset("arm64")}]}
  | if (.version | length) > 0 then . else error("missing version") end
' <<<"$rel"
