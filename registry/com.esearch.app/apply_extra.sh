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
# Upstream fixes the executable name to e-search; fail if its layout changes.
[ -f esearch/e-search ] && [ -x esearch/e-search ] && [ -f esearch/resources/app/package.json ] || {
    echo "portable app launcher or resources missing" >&2
    exit 1
}
# The setuid helper is unused under zypak.
chmod -R a-s esearch
rm -rf stage esearch.tar.gz
