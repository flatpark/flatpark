#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f procraft.tar.gz ] || { echo "missing procraft.tar.gz" >&2; exit 1; }
rm -rf stage procraft
mkdir stage
bsdtar --no-same-owner -xf procraft.tar.gz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] && [ -x "$1/bin/procraft" ] || { echo "unexpected ProCraft archive layout" >&2; exit 1; }
mv "$1" procraft
rm -rf stage procraft.tar.gz
