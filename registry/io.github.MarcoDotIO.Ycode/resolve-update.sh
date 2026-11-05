#!/usr/bin/env bash
# Update resolver for Ycode.
#
# Prints the newest release and its two Linux tarballs as JSON on stdout; logs
# go to stderr. Ycode's releases are still marked pre-release on GitHub
# (1.0.0-beta.N), which /releases/latest skips, so this reads the release list.
#
# It takes the newest published, non-draft release that carries both
# Ycode-<v>-x86_64.tar.xz and Ycode-<v>-aarch64.tar.xz, so a release whose
# assets are still uploading, or one with only the macOS .dmg, is skipped
# rather than failing the sweep. Once any full (non-pre-release) release
# exists, only full releases are considered: the stable branch then never moves
# onto a later beta. Until then, betas are what upstream ships.
set -euo pipefail

repo="MarcoDotIO/Ycode"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30")"

rel="$(jq -c '
  map(select(.draft | not)
      | . as $r | ($r.tag_name | ltrimstr("v")) as $v
      | select([$r.assets[].name] | (index("Ycode-\($v)-x86_64.tar.xz") and index("Ycode-\($v)-aarch64.tar.xz"))))
  | map(select(.prerelease | not)) as $full
  | (if ($full | length) > 0 then $full else . end)
  | sort_by(.published_at) | last // empty' <<<"$rels")"

[ -n "$rel" ] || { echo "no Ycode release carries both Linux tarballs" >&2; exit 1; }

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
asset() { jq -r --arg n "Ycode-$version-$1.tar.xz" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel"; }
url="$(asset x86_64)"
url_arm="$(asset aarch64)"

[ -n "$version" ] && [ -n "$url" ] && [ -n "$url_arm" ] ||
    { echo "failed to resolve a Ycode release with both Linux tarballs" >&2; exit 1; }
echo "resolved Ycode $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" --arg r "$(jq -r '.html_url' <<<"$rel")" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[{filename:"ycode.tar.xz", arch:"x86_64", url:$u}, {filename:"ycode.tar.xz", arch:"aarch64", url:$ua}]}'
