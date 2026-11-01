#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
for f in audacity.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools=appimage-tools/bin
offset="$("$tools/appimage-offset" audacity.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "invalid AppImage offset: $offset" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" audacity.AppImage >/dev/null
[ -x squashfs-root/AppRun ] || { echo "AppImage has no executable AppRun" >&2; exit 1; }
[ -x squashfs-root/bin/audacity4portable ] || { echo "AppImage has no Audacity executable" >&2; exit 1; }
mv squashfs-root audacity
rm -rf appimage-tools audacity.AppImage appimage-tools.tar.xz
