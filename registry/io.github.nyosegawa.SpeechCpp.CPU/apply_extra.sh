#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f speech.zip ] || { echo "missing extra-data: speech.zip" >&2; exit 1; }
rm -rf stage speech
mkdir stage
# System installs run as root with no capabilities; never restore ownership.
bsdtar --no-same-owner -xf speech.zip -C stage
# Official portable releases have a flat layout. Fail updates if that changes.
[ -x stage/speech ] || { echo "speech executable missing from release" >&2; exit 1; }
[ -f stage/libspeech.so.4 ] || { echo "libspeech shared library missing from release" >&2; exit 1; }
mv stage speech
rm speech.zip
