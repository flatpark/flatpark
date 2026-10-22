#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# Linux download is a linuxdeploy AppImage: an ELF stub with a SquashFS
# appended. It is never executed or FUSE-mounted; appimage-offset (from the
# appimage-tools extra-data) finds where the SquashFS starts and unsquashfs
# unpacks the AppDir from there, whole, to /app/extra/opencloud. The tree stays
# as shipped: usr/bin and usr/lib must remain siblings for the binaries'
# $ORIGIN/../lib RUNPATH and usr/bin/qt.conf.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in opencloud.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf opencloud appimage-tools

# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring an archive's owner would fail.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" opencloud.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d opencloud opencloud.AppImage >/dev/null

# linuxdeploy's AppRun ends in `exec AppRun.wrapped`, a symlink to the client.
# The wrappers run usr/bin/opencloud and usr/bin/opencloudcmd; fail here, not
# at launch, if a release moves them.
for b in opencloud opencloudcmd; do
    [ -x "opencloud/usr/bin/$b" ] || { echo "usr/bin/$b missing from the AppDir" >&2; exit 1; }
done
[ -f opencloud/usr/bin/qt.conf ] || { echo "usr/bin/qt.conf missing from the AppDir" >&2; exit 1; }

rm -rf opencloud.AppImage appimage-tools.tar.xz appimage-tools
