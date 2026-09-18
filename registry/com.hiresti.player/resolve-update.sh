#!/usr/bin/env bash
# Update resolver for HiresTI.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "1.9.7", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "hiresti.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="yelanxin/hiresTI"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Upstream ships one .deb per Debian/Ubuntu release plus .rpm and Arch .pkg. The
# ubuntu2604 .deb is the build target: the payload bundles Pillow,
# charset_normalizer and setproctitle as compiled CPython extension modules
# (`*.cpython-3XX-x86_64-linux-gnu.so`) and imports them with the runtime's own
# interpreter, so the .deb's Python generation has to be the runtime's.
# org.gnome.Platform//51 ships Python 3.14, which only loads `cpython-314`
# modules, and ubuntu2604 is the asset built against it. Pick it explicitly.
url="$(jq -r '.assets[] | select(.name | test("_amd64_ubuntu2604\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve hiresTI release" >&2; exit 1; }
echo "resolved hiresTI $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"hiresti.deb", url:$u}]}'
