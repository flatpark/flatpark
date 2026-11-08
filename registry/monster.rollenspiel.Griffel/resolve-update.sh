#!/usr/bin/env bash
# Update resolver for Griffel.
#
# Prints the current stable version and the installable tarball as JSON on
# stdout:
#   { "version": "0.4.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "griffel.tar.gz", "url": "..." } ],
#     "releaseUrl": "..." }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size itself. The version is compared
# against the latest <release> in the AppStream metainfo.
#
# Upstream is a Forgejo instance, so this reads the Gitea-compatible API. Two
# differences to a GitHub resolver matter here:
#   * there is no /releases/latest, so every release is listed and sorted;
#   * releases are marked pre-release while they are being written up, so the
#     filter has to be explicit — the catalog ships what upstream calls stable.
set -euo pipefail

api="https://git.rollenspiel.monster/api/v1/repos/Tealk/griffel"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

releases="$(curl -fsSL "$api/releases?limit=50")"

# Highest v<major>.<minor>.<patch> among drafts=false, prerelease=false.
release="$(jq -c '
    [ .[] | select(.draft == false and .prerelease == false) ]
    | map(select(.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")))
    | sort_by(.tag_name | ltrimstr("v") | split(".") | map(tonumber))
    | last' <<<"$releases")"

if [ "$release" = "null" ]; then
    echo "no stable release with a v<major>.<minor>.<patch> tag found" >&2
    echo "a release still flagged pre-release is skipped on purpose" >&2
    exit 1
fi

tag="$(jq -r '.tag_name' <<<"$release")"
version="${tag#v}"
date="$(jq -r '.published_at' <<<"$release" | cut -c1-10)"
release_url="$(jq -r '.html_url // ""' <<<"$release")"
url="$(jq -r 'first(.assets[] | select(.name | test("^Griffel-.*-linux\\.tar\\.gz$")) | .browser_download_url)' <<<"$release")"

[ -n "$url" ] && [ "$url" != "null" ] || {
    echo "release $tag has no Griffel-*-linux.tar.gz asset (run 'make tarball' and attach it)" >&2
    exit 1
}

echo "resolved Griffel $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ru "$release_url" \
    '{version:$v, releaseDate:$d, sources:[{filename:"griffel.tar.gz", url:$u}]}
     + (if $ru == "" then {} else {releaseUrl:$ru} end)'
