#!/usr/bin/env bash
# Update resolver for Redot Engine: the newest stable GitHub release and its
# official Linux editor zips (x86_64 and arm64). Prints
# { "version", "releaseDate", "sources": [...] } on stdout; logs go to stderr.
set -euo pipefail

repo="Redot-Engine/redot-engine"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Not /releases/latest: upstream keeps an LTS line (26.2) beside the current
# one, and a later LTS patch release would become "latest" and move users back
# a version. Take the highest version among stable, non-prerelease tags
# (redot-<version>-stable).
rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=50")"

version="$(jq -r '.[] | select(.draft == false and .prerelease == false)
                 | .tag_name | capture("^redot-(?<v>[0-9][0-9.]*)-stable$").v' <<<"$rels" \
           | sort -V | tail -n1)"
[ -n "$version" ] || { echo "no stable redot release found" >&2; exit 1; }

rel="$(jq --arg t "redot-${version}-stable" '.[] | select(.tag_name == $t)' <<<"$rels")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
asset() { jq -r --arg name "$1" '.assets[] | select(.name == $name) | .browser_download_url' <<<"$rel" | head -n1; }
# The non-mono editor builds; the mono ones need a .NET SDK the sandbox lacks.
url_x64="$(asset "Redot_v${version}-stable_linux_x64.zip")"
url_arm64="$(asset "Redot_v${version}-stable_linux_arm64.zip")"

[ -n "$url_x64" ] && [ -n "$url_arm64" ] || { echo "failed to resolve Linux zips for redot $version" >&2; exit 1; }
echo "resolved redot $version ($date): $url_x64 $url_arm64" >&2

jq -n --arg v "$version" --arg d "$date" --arg x "$url_x64" --arg a "$url_arm64" \
  '{version:$v, releaseDate:$d, sources:[
     {arch:"x86_64",  filename:"redot.zip", url:$x},
     {arch:"aarch64", filename:"redot.zip", url:$a}]}'
