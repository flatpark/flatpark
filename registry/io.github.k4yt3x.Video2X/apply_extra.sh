#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
for f in video2x.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf video2x squashfs-root appimage-tools
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools=appimage-tools/bin
offset="$("$tools/appimage-offset" video2x.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "invalid AppImage offset: $offset" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" video2x.AppImage >/dev/null
# AppRun is upstream's stable link to the CLI; keep its relative library and
# model paths intact, and fail updates that no longer contain the CLI layout.
[ -x squashfs-root/AppRun ] || { echo "missing executable AppRun" >&2; exit 1; }
[ -d squashfs-root/usr/share/video2x/models ] || { echo "missing Video2X models" >&2; exit 1; }
mv squashfs-root video2x
rm -rf appimage-tools video2x.AppImage appimage-tools.tar.xz
