#!/usr/bin/env bash
# Update resolver for Open DroneLog.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "3.3.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "open-dronelog.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="arpanghosh8453/open-dronelog"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags carry no leading `v` today (e.g. `3.3.0`); ltrimstr is a no-op then and
# still does the right thing if that ever changes.
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Match the asset by its exact name, version included. A loose `*_linux_amd64.deb`
# suffix match is not enough: the 3.3.1 release carries BOTH
# open-dronelog_3.3.1_linux_amd64.deb and a leftover
# open-dronelog_3.3.0_linux_amd64.deb, and picking by sort order took the 3.3.0
# one — a package that installed as "3.3.1" and then reported 3.3.0 in its own
# About box, with an update banner pointing at the version it claimed to be.
url="$(jq -r --arg v "$version" \
  '.assets[] | select(.name == ("open-dronelog_" + $v + "_linux_amd64.deb")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve open-dronelog_${version}_linux_amd64.deb" >&2; exit 1; }
echo "resolved open-dronelog $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"open-dronelog.deb", url:$u}]}'
