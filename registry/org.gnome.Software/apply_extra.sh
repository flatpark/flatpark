#!/bin/sh
# Unpacks gnome-software-next-VERSION-ARCH.tar.xz into /app/extra at
# install time, to the fixed path the build was made for.
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f app.tar.xz ] || { echo "app.tar.xz missing" >&2; exit 1; }
rm -rf stage gnome-software-next
mkdir stage
bsdtar --no-same-owner -xf app.tar.xz -C stage
set -- stage/gnome-software-next-*
[ $# -eq 1 ] && [ -d "$1" ] || { echo "expected one gnome-software-next-* directory" >&2; exit 1; }
mv "$1" gnome-software-next
rm -rf stage app.tar.xz
[ -x gnome-software-next/bin/gnome-software ] || { echo "gnome-software missing" >&2; exit 1; }
