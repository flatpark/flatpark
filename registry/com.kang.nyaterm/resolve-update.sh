#!/usr/bin/env bash
# Update resolver for NyaTerm.
#
# Prints the current version + the Linux x86_64 and arm64 .debs as JSON on
# stdout:
#   { "version": "2.0.6", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "nyaterm.deb", "arch": "x86_64", "url": "..." },
#                  { "filename": "nyaterm.deb", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark reads the
# assets' digest and size from the releases API. The version is compared
# against the latest <release> in the AppStream metainfo.
#
# Only plain `vX.Y.Z` tags are followed. Upstream compiles the flavour in from
# the version: a pre-release tag (`-preview.N`, `-beta.N`, `-rc.N`) builds
# "NyaTerm Preview", with its own data directory and window id, so it must
# never land in this package. The rolling `main-snapshot` is skipped the same
# way.
set -euo pipefail

repo="nyakang/nyaterm"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30")"

read -r version date x64 arm64 < <(
  jq -r '
    map(select(.draft == false and .prerelease == false
               and (.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))))
    | sort_by(.published_at) | reverse
    | map(.tag_name as $t | ($t | ltrimstr("v")) as $v | {
        v: $v,
        d: (.published_at | .[0:10]),
        x: ([.assets[]? | select(.name == "NyaTerm_\($v)_linux_x64.deb") | .browser_download_url][0]),
        a: ([.assets[]? | select(.name == "NyaTerm_\($v)_linux_arm64.deb") | .browser_download_url][0])
      })
    | map(select(.x != null and .a != null))
    | .[0] // empty
    | "\(.v) \(.d) \(.x) \(.a)"
  ' <<<"$rels"
)

[ -n "${version:-}" ] && [ -n "${x64:-}" ] && [ -n "${arm64:-}" ] \
  || { echo "failed to resolve NyaTerm release" >&2; exit 1; }
echo "resolved NyaTerm $version ($date): $x64 $arm64" >&2

jq -n --arg v "$version" --arg d "$date" --arg x "$x64" --arg a "$arm64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"nyaterm.deb", arch:"x86_64",  url:$x},
     {filename:"nyaterm.deb", arch:"aarch64", url:$a}]}'
