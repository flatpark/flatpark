#!/usr/bin/env bash
# Update resolver for Nutstore (坚果云).
#
# The client's own updater reads latestVersion: one entry per platform, each
# with a stable build (stVer/stUrl) and a staged-rollout build (exVer/exUrl,
# exPercent). This package follows the stable x86_64 build, "linux-jdk7-x64"
# (the name is historical; the tarball bundles a Java 21 runtime).
set -euo pipefail

feed="$(curl -fsSL 'https://www.jianguoyun.com/static/exe/latestVersion?cache=false')"
version="$(jq -r '.[] | select(.OS == "linux-jdk7-x64") | .stVer' <<<"$feed")"
url="$(jq -r '.[] | select(.OS == "linux-jdk7-x64") | .stUrl' <<<"$feed")"

if [[ ! "$url" =~ /nutstore_client-${version//./\\.}-linux-x86_64-public\.tar\.gz$ ]]; then
    echo "unexpected Nutstore download for $version: $url" >&2
    exit 1
fi

# The feed has no release date; the file's Last-Modified is when it was published.
release_date=""
last_modified="$(curl -fsSLI "$url" | tr -d '\r' | sed -n 's/^[Ll]ast-[Mm]odified: //p' | tail -1)"
if [ -n "$last_modified" ]; then
    release_date="$(date -u -d "$last_modified" +%Y-%m-%d 2>/dev/null || true)"
fi

jq -n --arg v "$version" --arg d "$release_date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"nutstore.tar.gz", url:$u}]}'
