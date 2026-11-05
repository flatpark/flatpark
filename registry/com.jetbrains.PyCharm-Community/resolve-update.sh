#!/usr/bin/env bash
# Both IntelliJ and PyCharm publish here. Only stable pycharm/* tags qualify.
set -euo pipefail
headers=()
[ -z "${GITHUB_TOKEN:-}" ] || headers=(-H "Authorization: Bearer $GITHUB_TOKEN")
for page in 1 2 3 4 5; do
    releases="$(curl -fsSL "${headers[@]}" \
        "https://api.github.com/repos/JetBrains/intellij-community/releases?per_page=100&page=$page")"
    release="$(jq -c '[.[] | select(.draft == false and .prerelease == false) |
        select(.tag_name | test("^pycharm/[0-9]+[.][0-9]+([.][0-9]+)*$"))][0] // empty' <<<"$releases")"
    [ -z "$release" ] || break
    [ "$(jq length <<<"$releases")" -gt 0 ] || break
done
[ -n "$release" ] || { echo "no stable PyCharm Community release found" >&2; exit 1; }
jq -e '
  (.tag_name | sub("^pycharm/"; "")) as $v |
  ["x86_64", "aarch64"] as $arches |
  {version: $v, releaseDate: (.published_at | split("T")[0]), releaseUrl: .html_url,
   sources: [ $arches[] as $arch |
     ("pycharm-" + $v + (if $arch == "aarch64" then "-aarch64" else "" end) + ".tar.gz") as $name |
     ([.assets[] | select(.name == $name)] | if length == 1 then .[0] else error("missing or ambiguous asset: " + $name) end) |
     {filename: "pycharm.tar.gz", url: .browser_download_url, arch: $arch} ]}
' <<<"$release"
