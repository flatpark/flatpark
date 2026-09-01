#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# OpenShot for Linux ONLY as an AppImage — no .deb, no .rpm, no plain tarball —
# so this repackages that. An AppImage is not a special format: a type-2 one is
# an ELF stub with a SquashFS filesystem concatenated after it. It never has to
# be executed or FUSE-mounted to read it; the appended filesystem is unpacked
# directly.
#
# Two tools do that, both from the appimage-tools extra-data fetched alongside
# the AppImage:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset (gzip/xz/lz4/zstd; OpenShot's is
#                    gzip)
#
# The result is the AppDir, staged whole at a stable path the wrapper execs:
# /app/extra/openshot. Its layout is AppRun + usr/, and usr/bin holds a
# self-contained tree — the openshot-qt launcher, its bundled Python/PyQt5/
# libopenshot/FFmpeg .so files, Qt plugins, and openshot-qt-launch, the vendor's
# own wrapper that sets LD_LIBRARY_PATH / QT_PLUGIN_PATH relative to itself.
#
# The desktop file, icon, MIME definition and AppStream metainfo are shipped by
# the manifest at *build* time — extra-data is fetched later on the user's
# machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f openshot.AppImage ]      || { echo "missing extra-data: openshot.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ]  || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine. Both the
# tarball below and unsquashfs (via -no-xattrs, and it never chowns) are safe
# under that constraint.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" openshot.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf openshot
# -no-xattrs: the apply_extra sandbox has all capabilities dropped and cannot
# set security xattrs; -d writes straight to the final path, no rename needed.
"$tools/unsquashfs" -no-xattrs -o "$offset" -d openshot openshot.AppImage

[ -x openshot/usr/bin/openshot-qt-launch ] || { echo "openshot-qt-launch missing after unpack" >&2; exit 1; }
[ -x openshot/usr/bin/openshot-qt ]        || { echo "openshot-qt binary missing after unpack" >&2; exit 1; }

# Drop the 254 MB AppImage and the extractor now that the tree is staged —
# otherwise both sit on the user's disk for the life of the install.
rm -rf openshot.AppImage appimage-tools.tar.xz appimage-tools
