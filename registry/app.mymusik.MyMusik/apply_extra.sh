#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
for file in MyMusik.AppImage appimage-tools.tar.xz; do
    [ -f "$file" ] || { echo "Missing extra-data: $file" >&2; exit 1; }
done
bsdtar --no-same-owner -xf appimage-tools.tar.xz
offset="$(appimage-tools/bin/appimage-offset MyMusik.AppImage)"
case "$offset" in ''|*[!0-9]*) echo "Invalid AppImage offset: $offset" >&2; exit 1 ;; esac
appimage-tools/bin/unsquashfs -q -no-xattrs -o "$offset" -d mymusik MyMusik.AppImage
[ -x mymusik/AppRun ] && [ -x mymusik/usr/bin/DesktopApp ] || { echo 'Missing MyMusik launcher' >&2; exit 1; }
rm -rf MyMusik.AppImage appimage-tools.tar.xz appimage-tools
