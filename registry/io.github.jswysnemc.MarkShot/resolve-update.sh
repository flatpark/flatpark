#!/usr/bin/env bash
# Update resolver for Mark Shot.
#
# Prints the current version + upstream's portable Linux tarball for each arch
# as JSON on stdout:
#   { "version": "0.2.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "mark-shot.tar.gz", "url": "...", "arch": "x86_64" },
#                  { "filename": "mark-shot.tar.gz", "url": "...", "arch": "aarch64" } ] }
# Logs go to stderr. No hashing, no manifest rewriting - update-pins reads the
# GitHub asset's digest and size. The version is compared against the latest
# <release> in the AppStream metainfo.
set -euo pipefail

repo="jswysnemc/mark-shot"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags are `v<version>`. Since 0.2.0 (the Rust rewrite) the portable build is
# `mark-shot-native-<version>-linux-<arch>.tar.gz`; the release also carries an
# AppImage (x86_64 only), a Flatpak bundle and per-distribution .deb/.rpm
# packages. Matched by exact name and anchored on the version so no other
# asset can be picked.
jq -e '
  (.tag_name | ltrimstr("v")) as $version |
  def asset($arch):
    [.assets[] | select(.name == ("mark-shot-native-" + $version + "-linux-" + $arch + ".tar.gz"))] |
    if length == 1 then .[0].browser_download_url
    else error("failed to resolve mark-shot release: no " + $arch + " tarball for " + $version) end;
  {version: $version, releaseDate: (.published_at | split("T")[0]),
   sources: [{filename: "mark-shot.tar.gz", url: asset("x86_64"), arch: "x86_64"},
             {filename: "mark-shot.tar.gz", url: asset("aarch64"), arch: "aarch64"}]} |
  if (.version | length) > 0 and (.releaseDate | length) > 0 then . else error("missing release metadata") end
' <<<"$rel"
