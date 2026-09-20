#!/usr/bin/env bash
# Update resolver for HelixNotes.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "1.3.5", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "helixnotes.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

# HelixNotes is developed on GitLab, not GitHub: the releases API is
# /api/v4/projects/<url-encoded path>/releases and needs no token for a public
# project. Release assets are "links" pointing at upstream's own CDN
# (download.helixnotes.com), which is what we pin.
project="ArkHost%2FHelixNotes"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL "https://gitlab.com/api/v4/projects/$project/releases?per_page=20")"

# GitLab returns releases newest-first and has no "prerelease" flag; take the
# newest published release that actually carries the Linux x86_64 .deb, so a
# release that ships only some platforms is skipped rather than pinned empty.
# upcoming_release is GitLab's scheduled-in-the-future marker.
sel="$(jq -c '
  [ .[]
    | select(.upcoming_release != true)
    | { tag: .tag_name,
        date: .released_at,
        url: ( [ .assets.links[]? | select(.name | test("_amd64\\.deb$")) | .url ] | first ) }
    | select(.url != null)
  ] | first // empty' <<<"$rels")"

[ -n "$sel" ] || { echo "no HelixNotes release with a _amd64.deb asset" >&2; exit 1; }

version="$(jq -r '.tag | ltrimstr("v")' <<<"$sel")"
date="$(jq -r '.date' <<<"$sel" | cut -c1-10)"
url="$(jq -r '.url' <<<"$sel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve helixnotes release" >&2; exit 1; }
echo "resolved helixnotes $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"helixnotes.deb", url:$u}]}'
