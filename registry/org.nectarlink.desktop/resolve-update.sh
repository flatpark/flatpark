#!/usr/bin/env bash
# Update resolver for NectarLink.
#
# Prints the current version + upstream's portable Linux tarball as JSON on
# stdout:
#   { "version": "0.1.5", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "nectarlink.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting - update-pins reads the
# GitHub asset's digest and size. The version is compared against the latest
# <release> in the AppStream metainfo.
set -euo pipefail

repo="thtbee/nectarlink"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest skips upstream's "Nightly" pre-releases
# (v<version>-nightly.<n>), so only stable releases are followed.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags are `v<version>`; the portable build is
# `Nectarlink-<version>-linux-x86_64.tar.gz` (no aarch64 Linux build). The
# release also carries a .deb, an .rpm, an AppImage and an install.sh; the
# exact name, anchored on the version, keeps any of those from being picked.
jq -e '
  (.tag_name | ltrimstr("v")) as $version |
  [.assets[] | select(.name == ("Nectarlink-" + $version + "-linux-x86_64.tar.gz"))] as $a |
  if ($a | length) != 1 then error("failed to resolve nectarlink release: no linux-x86_64 tarball for " + $version) else . end |
  {version: $version, releaseDate: (.published_at | split("T")[0]),
   sources: [{filename: "nectarlink.tar.gz", url: $a[0].browser_download_url}]} |
  if (.version | length) > 0 and (.releaseDate | length) > 0 then . else error("missing release metadata") end
' <<<"$rel"
