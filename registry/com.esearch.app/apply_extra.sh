#!/bin/sh
set -eu
# Unpack the official portable tree offline, without restoring archive owners.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f esearch.tar.gz ] || { echo "missing esearch.tar.gz" >&2; exit 1; }
rm -rf stage esearch
mkdir stage
bsdtar --no-same-owner -xf esearch.tar.gz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one portable app directory" >&2; exit 1; }
mv "$1" esearch
# Discover the launcher from Electron's unique resources.pak sibling, excluding
# its helper executables. A renamed launcher continues to work after an update.
launcher=""
for f in esearch/*; do
    [ -f "$f" ] && [ -x "$f" ] || continue
    case "${f##*/}" in chrome-sandbox|chrome_crashpad_handler|*.so|*.so.*) continue ;; esac
    [ -z "$launcher" ] || { echo "ambiguous app launcher" >&2; exit 1; }
    launcher="${f##*/}"
done
[ -n "$launcher" ] && [ -f esearch/resources/app/package.json ] || { echo "portable app launcher or resources missing" >&2; exit 1; }
printf '%s\n' "$launcher" > launcher-path
# The setuid helper is unused under zypak.
chmod -R a-s esearch
rm -rf stage esearch.tar.gz
