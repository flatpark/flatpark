#!/bin/sh
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f recgo.deb ] || { echo "missing extra-data: recgo.deb" >&2; exit 1; }

rm -rf stage recgo
mkdir stage
if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xOf recgo.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
elif command -v ar >/dev/null 2>&1; then
    ar -x recgo.deb
    tar --no-same-owner -xf data.tar.* -C stage
    rm -f control.tar.* debian-binary data.tar.*
else
    echo "Neither bsdtar nor ar found" >&2
    exit 1
fi
[ -f stage/usr/bin/recgo ] || { echo "recgo binary not found in .deb" >&2; exit 1; }

mv stage/usr/bin/recgo recgo
chmod +x recgo

rm -rf stage recgo.deb
