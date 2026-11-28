#!/usr/bin/env bash
# Update resolver for OpenLogi.
#
# Prints the latest stable release and its two Linux .debs (amd64, arm64) as
# JSON on stdout, one source per arch under the same filename. Logs go to
# stderr. FlatPark reads each asset's digest and size from the releases API.
# releases/latest skips upstream's frequent -beta prereleases.
set -euo pipefail

repo="AprilNEA/OpenLogi"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

tag="$(jq -r '.tag_name' <<<"$rel")"
version="${tag#v}"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Exact names: the release also carries .rpm, .pkg.tar.zst, .flatpak, their
# .minisig signatures, and the macOS and Windows builds.
x86_64="$(jq -r --arg t "$tag" '.assets[] | select(.name == "openlogi-\($t)-linux-amd64.deb") | .browser_download_url' <<<"$rel")"
aarch64="$(jq -r --arg t "$tag" '.assets[] | select(.name == "openlogi-\($t)-linux-arm64.deb") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$x86_64" ] && [ -n "$aarch64" ] \
  || { echo "failed to resolve OpenLogi release" >&2; exit 1; }
echo "resolved openlogi $version ($date): $x86_64" >&2

jq -n --arg v "$version" --arg d "$date" --arg x "$x86_64" --arg a "$aarch64" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"openlogi.deb", arch:"x86_64",  url:$x},
     {filename:"openlogi.deb", arch:"aarch64", url:$a}
   ]}'
