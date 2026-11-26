#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f nano.tar.gz ] || { echo 'missing nano.tar.gz' >&2; exit 1; }
rm -rf stage nano
mkdir stage
bsdtar --no-same-owner -xf nano.tar.gz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo 'expected one application directory' >&2; exit 1; }
mv "$1" nano
[ -x nano/nano-reader ] && [ -x nano/host/bin/yomi-host ] && [ -x nano/host/jre/bin/java ] || { echo 'missing Nano executable or bundled host' >&2; exit 1; }
rm -rf stage nano.tar.gz
