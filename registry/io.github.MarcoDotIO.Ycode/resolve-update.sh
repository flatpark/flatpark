#!/usr/bin/env bash
# Update resolver for Ycode.
#
# Prints the newest release and its two Linux tarballs as JSON on stdout; logs
# go to stderr. Ycode's releases are still marked pre-release on GitHub
# (1.0.0-beta.N), which /releases/latest skips, so this reads the release list
# and takes the newest published one that is not a draft.
set -euo pipefail

repo="MarcoDotIO/Ycode"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=20" |
       jq 'map(select(.draft | not)) | sort_by(.published_at) | last')"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
asset() { jq -r --arg n "Ycode-$version-$1.tar.xz" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel"; }
url="$(asset x86_64)"
url_arm="$(asset aarch64)"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] && [ -n "$url_arm" ] ||
    { echo "failed to resolve a Ycode release with both Linux tarballs" >&2; exit 1; }
echo "resolved Ycode $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" --arg r "$(jq -r '.html_url' <<<"$rel")" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[{filename:"ycode.tar.xz", arch:"x86_64", url:$u}, {filename:"ycode.tar.xz", arch:"aarch64", url:$ua}]}'
