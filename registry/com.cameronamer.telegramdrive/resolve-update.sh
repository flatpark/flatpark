#!/usr/bin/env bash
# Update resolver for Telegram Drive.
#
# Prints the latest desktop version, release date and the official Linux x86_64
# .deb as JSON on stdout; logs go to stderr. Hashing and manifest rewriting are
# handled by FlatPark's update automation.
#
# The repository also publishes Android releases (tags "Androidv<version>"),
# which can be newer than the desktop release, so releases/latest is not used:
# the newest non-draft, non-prerelease release with a "v<version>" tag is. The
# .deb is matched on its _amd64.deb suffix, never assembled from the tag; an
# ambiguous match is an error.
set -euo pipefail

repo="caamer20/Telegram-Drive"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30")"
rel="$(jq -c '[.[] | select((.draft | not) and (.prerelease | not)
                            and (.tag_name | test("^v[0-9]+(\\.[0-9]+)*$")))]
              | sort_by(.published_at) | last // empty' <<<"$rels")"
[ -n "$rel" ] || { echo "no desktop release found" >&2; exit 1; }

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '[.assets[] | select(.name | test("^Telegram\\.Drive_[0-9.]+_amd64\\.deb$")) | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"

[ -n "$version" ] && [ -n "$date" ] && [ -n "$url" ] || {
  echo "failed to resolve Telegram Drive release" >&2
  exit 1
}
echo "resolved Telegram Drive $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.deb", url:$u}]}'
