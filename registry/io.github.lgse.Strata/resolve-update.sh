#!/usr/bin/env bash
# Update resolver for Strata.
#
# Prints the current version + the Linux x86_64 release tarball as JSON:
#   { "version": "0.21.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "strata.tar.gz", "url": "..." } ] }
# Logs go to stderr. Only the stable channel is followed: upstream publishes a
# nightly pre-release every day, and /releases/latest skips pre-releases.
set -euo pipefail

repo="lgse/strata"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Each release carries a tarball, a detached .debug file and a .sha256 per
# architecture. Match each arch's tarball exactly so neither the debug file nor
# the checksum can be picked up.
asset() {
  jq -r --arg n "strata-$version-$1-unknown-linux-gnu.tar.gz" \
    '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1
}
url="$(asset x86_64)"
url_arm="$(asset aarch64)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve strata release" >&2; exit 1; }
[ -n "$url_arm" ] || { echo "no aarch64 tarball in strata $version" >&2; exit 1; }
echo "resolved strata $version ($date): $url $url_arm" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"strata.tar.gz", arch:"x86_64", url:$u}, {filename:"strata.tar.gz", arch:"aarch64", url:$ua}]}'
