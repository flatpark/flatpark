#!/usr/bin/env bash
# Update resolver for Netcatty.
#
# Prints the current version + both official Linux .deb builds as JSON on
# stdout:
#   { "version": "1.1.83", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "netcatty.deb", "arch": "x86_64", "url": "..." },
#                  { "filename": "netcatty.deb", "arch": "aarch64", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting; FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Upstream publishes versioned GitHub releases; the tag_name is the version
# (with a leading "v") and published_at supplies the date. Each release ships
# Netcatty-<version>-linux-amd64.deb and -arm64.deb alongside macOS/Windows
# builds. An ambiguous asset match is an error rather than a silent
# first-match, and the resolved URL is constrained to upstream's own release
# download host because the daily update job pins it into the manifest
# unattended.
set -euo pipefail

repo="binaricat/Netcatty"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"

[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || {
  echo "unexpected Netcatty tag: $(jq -r .tag_name <<<"$rel")" >&2
  exit 1
}

# Version-pinned deb URLs on GitHub's release download host. A tag that has no
# published deb yet must fail loudly instead of shipping a dead URL.
url_amd="$(jq -r --arg v "$version" '[.assets[] | select(.name == "Netcatty-\($v)-linux-amd64.deb") | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"
url_arm="$(jq -r --arg v "$version" '[.assets[] | select(.name == "Netcatty-\($v)-linux-arm64.deb") | .browser_download_url]
              | if length == 1 then .[0] else empty end' <<<"$rel")"
[ -n "$url_amd" ] && [ -n "$url_arm" ] && [ -n "$date" ] || {
  echo "failed to resolve Netcatty release" >&2
  exit 1
}
for u in "$url_amd" "$url_arm"; do
  case "$u" in
    https://github.com/binaricat/Netcatty/releases/download/*) ;;
    *) echo "refusing a download URL outside Netcatty's release host: $u" >&2; exit 1 ;;
  esac
  # GitHub release downloads answer a redirect to the object store, so follow
  # it with a one-byte range request instead of a bare HEAD (302 without -L).
  code="$(curl -fsSL -r 0-0 "$u" -o /dev/null -w '%{http_code}' || true)"
  case "$code" in 200 | 206) ;; *) echo "Netcatty names $version but $u answers $code" >&2; exit 1 ;; esac
done

echo "resolved Netcatty $version ($date): $url_amd | $url_arm" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url_amd" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[
     {filename:"netcatty.deb", arch:"x86_64", url:$u},
     {filename:"netcatty.deb", arch:"aarch64", url:$ua}
   ]}'
