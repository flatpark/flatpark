#!/usr/bin/env bash
# Update resolver for NyaTerm Preview.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "2.0.0-preview.4", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "nyaterm.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# The repo publishes two lines side by side: the stable Tauri 1.x releases
# (/releases/latest) and the GPUI 2.0 previews as GitHub prereleases tagged
# `vX.Y.Z-preview.N`, plus a rolling `main-snapshot`. The preview build is a
# separate flavour compiled in (its own data dir and window class), so this
# package follows only the `-preview.N` tags and never the stable line.
set -euo pipefail

repo="nyakang/nyaterm"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=50")"

read -r version date url < <(
  jq -r '
    map(select(.draft == false
               and (.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+-preview\\.[0-9]+$"))))
    | sort_by(.published_at) | reverse
    | map(.tag_name as $t | ($t | ltrimstr("v")) as $v | {
        v: $v,
        d: (.published_at | .[0:10]),
        u: (.assets[]? | select(.name == "NyaTerm_\($v)_linux_x64.deb") | .browser_download_url)
      })
    | map(select(.u != null))
    | .[0] // empty
    | "\(.v) \(.d) \(.u)"
  ' <<<"$rels"
)

[ -n "${version:-}" ] && [ -n "${url:-}" ] || { echo "failed to resolve NyaTerm preview release" >&2; exit 1; }
echo "resolved NyaTerm Preview $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"nyaterm.deb", url:$u}]}'
