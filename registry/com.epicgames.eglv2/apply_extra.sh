#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Epic's Linux
# launcher is a Tauri app shipped as a linuxdeploy AppImage: an ELF stub with
# a SquashFS appended, carrying its own GTK 3, WebKitGTK 4.1, GStreamer and the
# EOS SDK. It is never executed or FUSE-mounted; appimage-offset (from the
# appimage-tools extra-data) finds where the SquashFS starts and unsquashfs
# unpacks the AppDir from there, whole, to /app/extra/epic. The tree stays as
# shipped: the bundled WebKit finds its helper processes through paths
# relative to usr/, which the AppDir's own AppRun sets up.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in epic.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf epic appimage-tools

# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring an archive's owner would fail.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" epic.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d epic epic.AppImage >/dev/null

# The wrapper runs the AppDir's AppRun, which sources its GTK and GStreamer
# hooks and execs AppRun.wrapped; that one reads Exec= from the AppDir's
# desktop file. Fail here, not at launch, if a release changes that layout.
[ -x epic/AppRun ] && [ -x epic/AppRun.wrapped ] \
    || { echo "AppRun or AppRun.wrapped missing from the AppDir" >&2; exit 1; }
exe="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' epic/usr/share/applications/*.desktop | head -n1)"
[ -n "$exe" ] && [ -x "epic/usr/bin/$exe" ] \
    || { echo "launcher '$exe' named by the AppDir's desktop file not found in usr/bin" >&2; exit 1; }

rm -rf epic.AppImage appimage-tools.tar.xz appimage-tools
