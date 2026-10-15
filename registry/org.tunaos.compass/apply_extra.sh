#!/bin/sh
set -eu

# Runs offline at install time. Compass's Linux download is an AppImage: an ELF
# stub with a SquashFS filesystem appended. It is never executed or mounted;
# the appended filesystem is unpacked with the appimage-tools stack fetched
# alongside it (appimage-offset finds where the SquashFS starts, unsquashfs
# unpacks from there).
#
# The result is Compass's AppDir at /app/extra/compass. The wrapper runs the
# vendor's own AppRun from it, which starts usr/bin/compass with the bundled
# Node; the engine finds its helpers in usr/libexec/compass beside itself. The
# desktop files, icon and AppStream metainfo are installed by the manifest at
# build time, since extra-data only arrives on the user's machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f compass.AppImage ]      || { echo "missing extra-data: compass.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ] || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring recorded owners would fail.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" compass.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf compass
"$tools/unsquashfs" -no-xattrs -o "$offset" -d compass compass.AppImage

[ -x compass/AppRun ]                                   || { echo "AppRun missing after unpack" >&2; exit 1; }
[ -x compass/usr/bin/compass ]                          || { echo "usr/bin/compass missing after unpack" >&2; exit 1; }
[ -x compass/usr/bin/node ]                             || { echo "usr/bin/node missing after unpack" >&2; exit 1; }
[ -x compass/usr/libexec/compass/compass-sandbox-exec ] || { echo "compass-sandbox-exec missing after unpack" >&2; exit 1; }
[ -f compass/usr/share/compass/extension-runtime.js ]   || { echo "extension-runtime.js missing after unpack" >&2; exit 1; }

rm -rf compass.AppImage appimage-tools.tar.xz appimage-tools
