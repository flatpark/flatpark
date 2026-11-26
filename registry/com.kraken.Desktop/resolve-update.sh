#!/usr/bin/env bash
# Update resolver for Kraken Desktop.
#
# The download page links https://desktop-downloads.kraken.com/latest/<file>,
# which always serves the newest build. latest.json beside it names the
# version, the build's git revision and each file's sha256 and size, and the
# same files are served under /<revision>/, which does not move, so that is
# the URL pinned. With sha256 and size given, update-pins takes the pin
# without a download.
set -euo pipefail

base=https://desktop-downloads.kraken.com

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

meta="$(curl -fsSL "$base/latest.json")"
version="$(jq -r '.version' <<<"$meta")"
revision="$(jq -r '.revision' <<<"$meta")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$revision" =~ ^[0-9a-f]{40}$ ]] \
  || { echo "invalid latest.json: version=$version revision=$revision" >&2; exit 1; }

source_for() { # <arch> <latest.json files key>
  local file sha size
  file="$(jq -r --arg k "$2" '.files[$k].filename // empty' <<<"$meta")"
  sha="$(jq -r --arg k "$2" '.files[$k].sha256 // empty' <<<"$meta")"
  size="$(jq -r --arg k "$2" '.files[$k].size // empty' <<<"$meta")"
  [[ "$file" =~ ^kraken-[a-z0-9_]+-debian-linux-gnu\.deb$ && "$sha" =~ ^[0-9a-f]{64}$ && "$size" =~ ^[1-9][0-9]*$ ]] \
    || { echo "invalid latest.json entry for $2" >&2; return 1; }
  jq -n --arg a "$1" --arg u "$base/$revision/$file" --arg s "$sha" --argjson z "$size" \
    '{filename:"kraken.deb", arch:$a, url:$u, sha256:$s, size:$z}'
}
amd="$(source_for x86_64 linux-x86-debian)"
arm="$(source_for aarch64 linux-aarch64-debian)"

# latest.json carries no date; the file's Last-Modified is when it was published.
date="$(curl -fsSIL "$(jq -r .url <<<"$amd")" | awk -F': ' 'tolower($1)=="last-modified"{print $2}' | tr -d '\r' | tail -n1)"
date="$(date -u -d "$date" +%F 2>/dev/null || true)"

echo "resolved kraken desktop $version ($revision, ${date:-no date})" >&2
jq -n --arg v "$version" --arg d "$date" --argjson amd "$amd" --argjson arm "$arm" \
  '{version:$v, sources:[$amd,$arm]} + (if $d == "" then {} else {releaseDate:$d} end)'
