#!/usr/bin/env bash
# Update resolver for Couchtunes.
#
# Prints the newest release + its Linux x86_64 AppImage as JSON on stdout:
#   { "version": "2.16.7", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "couchtunes.AppImage", "url": "..." } ] }
# Logs go to stderr. GitHub's API carries the asset's sha256 and size, so
# update-pins pins it without a download.
#
# Prereleases are tracked on purpose: upstream cuts several `vX.Y.Z-beta.N`
# releases before each stable one, and this package ships them too, so FlatPark
# users get betas the way upstream's own beta Flatpak channel does. That is
# why this reads the release list rather than releases/latest, which skips
# prereleases. The newest non-draft release by publish time wins; a beta and
# the stable release cut from the same commit share created_at, so created_at
# can't order them. Each release is dated by day; when a beta and its stable
# release land the same day, Flatpak reports the version of the first <release>
# with the newest date, which is the one update-pins prepended last.
set -euo pipefail

repo="CaptechOmar/Couchtunes"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30")"
rel="$(jq -c '[ .[] | select(.draft | not) ] | sort_by(.published_at) | last // empty' <<<"$rels")"
[ -n "$rel" ] || { echo "no published couchtunes release" >&2; exit 1; }

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# `Couchtunes-<base version>-linux-x86_64.AppImage` (a beta's file carries the
# version it leads up to, without -beta.N). Anchored on the full shape so a
# zsync file or another arch is never picked.
url="$(jq -r '.assets[] | select(.name | test("^Couchtunes-[0-9][0-9.]*-linux-x86_64\\.AppImage$")) | .browser_download_url' <<<"$rel")"

# The newest release must carry the file. Falling back to an older release
# would look like a new version to update-pins (it only checks equality) and
# roll users back; a release whose AppImage isn't uploaded yet is retried on
# the next run instead.
[ -n "$version" ] || { echo "failed to read the couchtunes version" >&2; exit 1; }
[ "$(grep -c . <<<"$url")" = 1 ] || { echo "expected one Linux AppImage on couchtunes $version, found: ${url:-none}" >&2; exit 1; }
echo "resolved couchtunes $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"couchtunes.AppImage", url:$u}]}'
