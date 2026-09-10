#!/usr/bin/env bash
# Update resolver for NoteGen.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.36.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "note-gen.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting - FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="codexu/note-gen"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

# Tags are `note-gen-v<version>`.
version="$(jq -r '.tag_name | sub("^note-gen-v";"") | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux build we package is `NoteGen_<version>_amd64.deb`; the .rpm, the
# AppImage and the macOS/Windows/Android artifacts of the same release are
# skipped. Anchored on the version so a stray asset cannot match.
url="$(jq -r --arg v "$version" \
        '.assets[] | select(.name == "NoteGen_\($v)_amd64.deb") | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve note-gen release" >&2; exit 1; }
echo "resolved note-gen $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"note-gen.deb", url:$u}]}'
