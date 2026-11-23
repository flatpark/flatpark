#!/usr/bin/env bash
# Update resolver for Hypersomnia. Upstream serves /builds/latest/, whose
# version-AppImage.txt names the current release; the same bytes are kept under
# the versioned /builds/<version>/ directory, so the pin uses that stable URL
# instead of the moving "latest" one. Prints { "version", "releaseDate",
# "sources": [...] } on stdout; logs go to stderr. FlatPark downloads the URL
# and computes the sha256/size itself.
set -euo pipefail

base="https://hypersomnia.io/builds"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# The file is the version on its first line, then the commit hash and an SSH
# signature. Take only the first line and insist it looks like a release.
version_file="$(curl -fsSL "$base/latest/version-AppImage.txt")"
version="${version_file%%$'\n'*}"
version="${version%$'\r'}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.+-][0-9A-Za-z.+-]+)?$ ]]; then
    echo "unexpected version line: '$version'" >&2
    exit 1
fi

url="$base/$version/Hypersomnia.AppImage"
headers="$(curl -fsSI "$url")" || { echo "no AppImage at $url" >&2; exit 1; }

# Upstream's build upload time is the release date. Date is optional in the
# output; leave it out rather than fail an update if the header disappears.
date=""
modified="$(printf '%s\n' "$headers" | tr -d '\r' | sed -n 's/^[Ll]ast-[Mm]odified: //p' | head -n1)"
if [ -n "$modified" ]; then
    date="$(date -u -d "$modified" +%Y-%m-%d 2>/dev/null || true)"
fi

echo "resolved hypersomnia $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"Hypersomnia.AppImage", url:$u}]} | if $d == "" then del(.releaseDate) else . end'
