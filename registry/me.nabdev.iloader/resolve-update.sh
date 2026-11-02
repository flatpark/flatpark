#!/usr/bin/env bash
set -euo pipefail
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} https://api.github.com/repos/nab138/iloader/releases/latest)"
# Require exactly one official Debian asset for each supported architecture.
jq -e '
  def asset($name; $arch):
    [.assets[] | select(.name == $name)] |
    if length != 1 then error("expected one " + $name) else
      .[0] | {filename:"iloader.deb", arch:$arch, url:.browser_download_url, size:.size}
    end;
  {version:(.tag_name | ltrimstr("v")), releaseDate:(.published_at[0:10]),
   sources:[asset("iloader-linux-amd64.deb"; "x86_64"), asset("iloader-linux-arm64.deb"; "aarch64")]}
  | if (.version | length) == 0 then error("missing version") else . end
' <<<"$rel"
