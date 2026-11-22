#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f electrum-ltc.AppImage ] && [ -f appimage-tools.tar.xz ] || { echo 'missing extra-data' >&2; exit 1; }
bsdtar --no-same-owner -xf appimage-tools.tar.xz
offset="$(appimage-tools/bin/appimage-offset electrum-ltc.AppImage)"
case "$offset" in ''|*[!0-9]*) echo 'invalid AppImage offset' >&2; exit 1;; esac
appimage-tools/bin/unsquashfs -no-xattrs -o "$offset" -d electrum-ltc electrum-ltc.AppImage
[ -x electrum-ltc/AppRun ] && [ -x electrum-ltc/usr/bin/python3 ] && [ -f electrum-ltc/usr/bin/electrum-ltc ] || { echo 'AppImage entry point missing' >&2; exit 1; }
rm -rf electrum-ltc.AppImage appimage-tools.tar.xz appimage-tools
