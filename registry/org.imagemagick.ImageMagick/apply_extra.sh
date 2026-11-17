#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f imagemagick.tar.xz ] || { echo "missing imagemagick.tar.xz" >&2; exit 1; }
rm -rf stage imagemagick
mkdir stage
bsdtar --no-same-owner -xf imagemagick.tar.xz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one top-level directory" >&2; exit 1; }
mv "$1" imagemagick
[ -x imagemagick/bin/magick ] && [ -f imagemagick/etc/ImageMagick-7/policy.xml ] || { echo "ImageMagick files missing" >&2; exit 1; }
rm -rf stage imagemagick.tar.xz
