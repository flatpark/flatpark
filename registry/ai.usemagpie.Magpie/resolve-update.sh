#!/usr/bin/env bash
# Resolve official Linux desktop assets, never the terminal-only CLI builds.
set -euo pipefail
for cmd in curl jq; do
  command -v "$cmd" >/dev/null || { echo "missing command: $cmd" >&2; exit 1; }
done
repo=yetone/magpie-releases
headers=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
rel="$(curl -fsSL --connect-timeout 15 --max-time 120 "${headers[@]}" \
  "https://api.github.com/repos/$repo/releases/latest")"
# Reject incomplete releases and ambiguous assets rather than publishing null URLs.
jq -e --arg repo "$repo" '
  . as $r |
  if (.draft == false and .prerelease == false
      and (.tag_name | type == "string")
      and (.tag_name | test("^v?[0-9]+\\.[0-9]+\\.[0-9]+$"))
      and (.published_at | type == "string")
      and (.published_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T")))
  then . else error("invalid stable release metadata") end |
  ["magpie-linux-amd64", "magpie-linux-arm64"] |
  map(. as $name |
    [$r.assets[] | select(.name == $name)] |
    if length == 1 then .[0] else error("missing or duplicate desktop asset: " + $name) end |
    if (.size > 0 and .state == "uploaded" and
        .browser_download_url == ("https://github.com/" + $repo + "/releases/download/" + $r.tag_name + "/" + $name))
    then {filename:$name, url:.browser_download_url}
    else error("invalid desktop asset: " + $name) end
  ) |
  {version:($r.tag_name | ltrimstr("v")), releaseDate:$r.published_at[0:10], sources:.}
' <<<"$rel"
