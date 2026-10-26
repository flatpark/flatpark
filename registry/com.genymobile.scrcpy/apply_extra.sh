#!/bin/sh
set -eu
# Unpack the official portable release offline, including its matching ADB
# and Android server. The versioned top directory becomes a stable path.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f scrcpy.tar.gz ] || { echo "missing extra-data: scrcpy.tar.gz" >&2; exit 1; }
rm -rf stage scrcpy
mkdir stage
bsdtar --no-same-owner -xf scrcpy.tar.gz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || {
    echo "expected one scrcpy release directory" >&2; exit 1;
}
mv "$1" scrcpy
[ -x scrcpy/scrcpy ] && [ -x scrcpy/adb ] && [ -s scrcpy/scrcpy-server ] || {
    echo "scrcpy executable, ADB or Android server missing from release" >&2; exit 1;
}
rm -rf stage scrcpy.tar.gz
