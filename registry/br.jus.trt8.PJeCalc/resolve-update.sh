#!/usr/bin/env bash
# Update resolver for PJe-Calc Cidadão.
#
# TRT8, which develops PJe-Calc for the Labour Courts, only serves its download
# server to connections from Brazil. LLawli/pjecalc-flatpak mirrors each new
# installer as a GitHub release, unchanged: a machine in Brazil checks TRT8's
# install page daily, downloads the new installer, checks it against the MD5
# TRT8 publishes next to the link and runs this package's apply_extra on it
# before releasing it (scripts/espelhar.sh there). The release is tagged
# v<version> and its body records TRT8's URL, MD5 and publication date.
#
# The Java runtime is Azul's Zulu 8 JRE, pinned here: PJe-Calc needs Java 8
# (Tomcat 7, Seam 2), and a newer JRE is a PR, not an automatic update, since
# the version compared is PJe-Calc's.
#
# Prints:
#   { "version": "2.16.0", "releaseDate": "2026-06-25", "sources": [
#       { "filename": "pjecalc-installer.exe", "url": "..." },
#       { "filename": "jre.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing: update-pins reads the asset's digest and size
# from the releases API.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

repo="LLawli/pjecalc-flatpak"
JRE_URL="https://cdn.azul.com/zulu/bin/zulu8.98.0.111-ca-jre8.0.512-linux_x64.tar.gz"

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name // empty' <<<"$rel" | sed -nE 's/^v([0-9]+(\.[0-9]+)+)$/\1/p')"
[ -n "$version" ] || { echo "no version in the latest release of $repo" >&2; exit 1; }
url="$(jq -r --arg n "pjecalc-$version-instalador-x64.exe" \
  '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel")"
[ -n "$url" ] || { echo "release v$version of $repo has no pjecalc-$version-instalador-x64.exe" >&2; exit 1; }

# TRT8's publication date, from the release body; the release date otherwise.
release_date="$(jq -r '.body // ""' <<<"$rel" \
  | sed -nE 's/.*Data de publicação no TRT8: ([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p' | head -n1)"
[ -n "$release_date" ] || release_date="$(jq -r '.published_at // "" | .[0:10]' <<<"$rel")"

echo "resolved PJe-Calc Cidadão $version (${release_date:-no date}): $url" >&2

jq -n \
  --arg v "$version" \
  --arg d "$release_date" \
  --arg u "$url" \
  --arg j "$JRE_URL" \
  '{version:$v} + (if $d == "" then {} else {releaseDate:$d} end)
   + {sources:[{filename:"pjecalc-installer.exe", url:$u}, {filename:"jre.tar.gz", url:$j}]}'
