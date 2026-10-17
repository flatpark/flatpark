#!/usr/bin/env bash
# Update resolver for Qoder.
#
# Prints the current version + the Linux .deb build as JSON on stdout:
#   { "version": "1.34.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "qoder-ide.deb", "arch": "x86_64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting; FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Upstream publishes no release index for the IDE download host, but the website
# changelog is backed by a GitHub-style releases API (the same one the download
# page reads). Each stable release's tag_name is the IDE version and its
# published_at supplies the date; the Linux deb is then fetched from upstream's
# own OSS host at a version-pinned path. Only x86_64 is published: the arm64
# path 404s, so this package is single-arch by upstream's own doing.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

api="https://repo.qoder.com/repos/QoderAI/changelog/releases?per_page=20&page=1"
json="$(curl -fsSL "$api" -H 'Accept: application/vnd.github.v3+json')"

printf '%s\n' "$json" | jq -e . >/dev/null 2>&1 || {
  echo "Qoder changelog API did not return JSON: $api" >&2
  exit 1
}

# Latest stable release; prereleases are never packaged.
version="$(printf '%s\n' "$json" | jq -r '[.[] | select(.prerelease != true)][0].tag_name // empty' | head -n 1 || true)"
date="$(printf '%s\n' "$json" | jq -r '[.[] | select(.prerelease != true)][0].published_at // empty' | head -n 1 || true)"

[ -n "$version" ] || {
  echo "no stable release found in Qoder changelog API: $api" >&2
  exit 1
}
date="${date:0:10}"

# Version-pinned deb URL on upstream's download host. Whatever the changelog
# answers is pinned into the manifest unattended by the daily update job, so
# constrain it to Qoder's own host and verify the artifact really exists: the
# versionless "latest" path lags behind the changelog, but a tag that has no
# published deb yet must fail loudly instead of shipping a dead URL.
url="https://download.qoder.com/release/$version/qoder-ide_amd64.deb"
case "$url" in
  https://download.qoder.com/release/*/qoder-ide_amd64.deb) ;;
  *) echo "refusing a download URL outside Qoder's download host: $url" >&2; exit 1 ;;
esac
code="$(curl -fsSI "$url" -o /dev/null -w '%{http_code}' || true)"
[ "$code" = "200" ] || {
  echo "Qoder changelog names $version but $url answers $code" >&2
  exit 1
}

echo "resolved Qoder $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"qoder-ide.deb", arch:"x86_64", url:$u}
   ]}'
