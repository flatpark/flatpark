#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
test -f writing-tools.tar.gz
rm -rf stage writing-tools
mkdir stage
bsdtar --no-same-owner -xf writing-tools.tar.gz -C stage
test -x stage/writing-tools/writing-tools
test -x stage/writing-tools/writing-tools-launcher
test -x stage/writing-tools/bin/xclip
test -f stage/writing-tools/lib/libXmu.so.6
mv stage/writing-tools writing-tools
rm -rf stage writing-tools.tar.gz
