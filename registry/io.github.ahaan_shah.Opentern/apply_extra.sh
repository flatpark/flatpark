#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
set -- opentern-*.tar.gz
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "expected one OpenTern archive" >&2; exit 1; }
archive=$1
rm -rf stage opentern
mkdir stage
bsdtar --no-same-owner -xf "$archive" -C stage
# Use the shipped desktop entry to identify the launcher; reject ambiguity.
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one archive directory" >&2; exit 1; }
mv "$1" opentern
launcher=$(sed -n 's/^Exec=//p' opentern/opentern.desktop)
case "$launcher" in ''|*[!a-zA-Z0-9_.-]*) echo "unexpected launcher" >&2; exit 1;; esac
[ -x "opentern/$launcher" ] || { echo "launcher missing" >&2; exit 1; }
printf '%s\n' "$launcher" > launcher-name
rm -rf stage "$archive"
