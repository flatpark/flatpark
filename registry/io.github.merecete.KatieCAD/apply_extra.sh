#!/bin/sh
set -eu

# Runs offline at install time. The official Linux archive is a tar.xz
# whose only member is the AppImage. That AppImage is read here, never
# executed and never FUSE-mounted.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in katiecad.tar.xz appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf katiecad squashfs-root appimage-tools stage
mkdir stage

bsdtar --no-same-owner --no-xattrs -xf appimage-tools.tar.xz
bsdtar --no-same-owner --no-xattrs -xf katiecad.tar.xz -C stage
set -- stage/*.AppImage
[ -f "$1" ] || { echo "AppImage not found in the archive" >&2; exit 1; }
mv "$1" katiecad.AppImage
rm -rf stage

tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" katiecad.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d squashfs-root katiecad.AppImage >/dev/null
[ -x squashfs-root/usr/lib/katiecad/KatieCAD ] \
    || { echo "KatieCAD not found in the AppImage" >&2; exit 1; }
mv squashfs-root katiecad

rm -rf katiecad.AppImage appimage-tools.tar.xz appimage-tools katiecad.tar.xz
chmod +x katiecad/AppRun katiecad/usr/lib/katiecad/KatieCAD
