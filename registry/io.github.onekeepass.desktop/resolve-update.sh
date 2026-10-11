#!/usr/bin/env bash
# Update resolver for OneKeePass.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.25.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "onekeepass.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="OneKeePass/desktop"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is the `OneKeePass_<version>_Linux_x86_64.deb` asset
# (the .AppImage/.rpm and the macOS/Windows builds are skipped). Always resolve
# the URL from the release's asset list rather than composing it from the tag:
# the asset name is upstream's to change, and a composed URL silently 404s on the
# next automated re-pin.
url="$(jq -r '.assets[] | select(.name | test("Linux_x86_64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
url_arm="$(jq -r '.assets[] | select(.name | test("Linux_aarch64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"
[ -n "$url_arm" ] || { echo "no aarch64 build in this release" >&2; exit 1; }

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve onekeepass release" >&2; exit 1; }
echo "resolved onekeepass $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  '{version:$v, releaseDate:$d, sources:[{filename:"onekeepass.deb", arch:"x86_64", url:$u}, {filename:"onekeepass.deb", arch:"aarch64", url:$ua}]}'
