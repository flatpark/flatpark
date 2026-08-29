#!/usr/bin/env bash
# Update resolver for FluxDown.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.4.7", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "fluxdown.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# The repo is a monorepo: alongside the desktop app it tags `server-*`,
# `mobile-*` and `cli-*` releases, plus frequent `-rc.N` prereleases. So this
# does not trust /releases/latest — it walks the releases list and takes the
# newest non-draft, non-prerelease whose tag is a bare `vX.Y.Z` and that
# actually carries the desktop `.deb` asset.
set -euo pipefail

repo="zerx-lab/FluxDown"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=50")"

read -r version date url < <(
  jq -r '
    map(select(.draft == false and .prerelease == false
               and (.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))))
    | sort_by(.published_at) | reverse
    | map({
        v: (.tag_name | ltrimstr("v")),
        d: (.published_at | .[0:10]),
        u: (.assets[]? | select(.name | test("-linux-x64\\.deb$")) | .browser_download_url)
      })
    | map(select(.u != null))
    | .[0] // empty
    | "\(.v) \(.d) \(.u)"
  ' <<<"$rels"
)

[ -n "${version:-}" ] && [ -n "${url:-}" ] || { echo "failed to resolve FluxDown release" >&2; exit 1; }
echo "resolved FluxDown $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"fluxdown.deb", url:$u}]}'
