#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
for f in darktable.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf darktable squashfs-root appimage-tools
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools=appimage-tools/bin
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }
offset="$("$tools/appimage-offset" darktable.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "invalid AppImage offset: $offset" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" darktable.AppImage >/dev/null
# AppRun sources the linuxdeploy GTK hook and starts usr/bin/darktable.
[ -x squashfs-root/AppRun ] || { echo "AppImage has no executable AppRun" >&2; exit 1; }
[ -x squashfs-root/usr/bin/darktable ] || { echo "AppImage has no usr/bin/darktable" >&2; exit 1; }
mv squashfs-root darktable
rm -rf appimage-tools darktable.AppImage appimage-tools.tar.xz
