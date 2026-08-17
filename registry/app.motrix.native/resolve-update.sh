#!/usr/bin/env bash
# Update resolver for Motrix.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "2.0.0-beta.18", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "motrix.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# This package follows upstream's 2.x channel INCLUDING prereleases: the 2.0.0
# betas are published several times a week and are far ahead of the last tagged
# stable (v1.8.19, May 2023), so "latest release" would pin a three-year-old
# build. Take whichever 2.x tag upstream published most recently, prerelease or
# not, so a 2.0.0 final is picked up the moment it lands.
#
# The `^v2\.` floor is deliberate: update-pins treats any version that differs
# from the metainfo as a bump, in either direction, so without it a backported
# v1.8.x hotfix published today would roll installed users back off the 2.x data
# format. Raise the floor when upstream opens a 3.x line — the loud stderr note
# below fires when a newer tag is being skipped, so it will not pass unnoticed.
set -euo pipefail

repo="agalwood/Motrix"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

releases="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=100")"

published="$(jq -c '[.[] | select(.draft | not)] | sort_by(.published_at) | reverse' <<<"$releases")"

# Tags are v<major>.<minor>.<patch> with an optional -beta.<n> suffix.
release="$(jq -c 'map(select(.tag_name | test("^v2\\.[0-9]+\\.[0-9]+(-beta\\.[0-9]+)?$"))) | first' <<<"$published")"
[ "$release" != "null" ] || { echo "no 2.x release found for $repo" >&2; exit 1; }

newest_tag="$(jq -r '.[0].tag_name // ""' <<<"$published")"
picked_tag="$(jq -r '.tag_name' <<<"$release")"
if [ -n "$newest_tag" ] && [ "$newest_tag" != "$picked_tag" ]; then
  echo "note: most recent upstream tag is $newest_tag; pinning $picked_tag (outside the 2.x channel this package tracks)" >&2
fi

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$release")"
date="$(jq -r '.published_at | split("T")[0]' <<<"$release")"
# Match the asset by its exact name. Every release also carries arm64 and (on the
# 1.x line) armv7l .debs plus .rpm/.exe/.dmg builds, and a loose suffix match
# would let sort order decide which one gets pinned.
url="$(jq -r --arg v "$version" \
  '.assets[] | select(.name == ("Motrix_" + $v + "_amd64.deb")) | .browser_download_url' <<<"$release")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve motrix release" >&2; exit 1; }
echo "resolved motrix $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"motrix.deb", url:$u}]}'
