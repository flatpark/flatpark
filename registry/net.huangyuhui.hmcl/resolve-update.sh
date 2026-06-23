#!/usr/bin/env bash
# Update resolver for HMCL.
#
# Prints the current version + two extra-data sources as JSON on stdout:
#   { "version": "3.14.1", "releaseDate": "YYYY-MM-DD", "sources": [
#       { "filename": "hmcl.jar",   "url": "...HMCL-<ver>.jar" },
#       { "filename": "jre.tar.gz", "url": "...Temurin 21 JRE tar.gz" } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URLs and computes each extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# HMCL is the launcher (version-tracked here); the Temurin JRE only provides the
# JVM — HMCL fetches JavaFX and per-version Minecraft JREs itself at runtime.
set -euo pipefail

repo="HMCL-dev/HMCL"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# Latest STABLE HMCL (releases/latest excludes the x.y.z.NNN pre-releases).
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
jar_url="$(jq -r '.assets[] | select(.name | test("^HMCL-[0-9.]+\\.jar$")) | .browser_download_url' <<<"$rel" | head -n1)"

# Latest Temurin 21 JRE (linux x64), self-contained tarball from Adoptium.
jre="$(curl -fsSL 'https://api.adoptium.net/v3/assets/latest/21/hotspot?os=linux&architecture=x64&image_type=jre')"
jre_url="$(jq -r '.[0].binary.package.link' <<<"$jre")"

[ -n "$version" ] && [ -n "$jar_url" ] && [ -n "$jre_url" ] \
  || { echo "failed to resolve HMCL sources" >&2; exit 1; }
echo "resolved HMCL $version ($date)" >&2
echo "  jar: $jar_url" >&2
echo "  jre: $jre_url" >&2

jq -n --arg v "$version" --arg d "$date" --arg j "$jar_url" --arg r "$jre_url" \
  '{version:$v, releaseDate:$d, sources:[
      {filename:"hmcl.jar",   url:$j},
      {filename:"jre.tar.gz", url:$r}
   ]}'
