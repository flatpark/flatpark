#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# xLights for Linux as an AppImage and a snap — no .deb, no .rpm, no plain
# tarball — so this repackages the AppImage. That is not a special format: a
# type-2 AppImage is an ELF stub with a SquashFS filesystem concatenated after
# it, and the appended filesystem can be read directly. It is never executed and
# never FUSE-mounted here.
#
# Two tools do that, both from the appimage-tools extra-data fetched alongside
# the AppImage:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset (xLights' is gzip)
#
# The result is the AppDir, staged whole at a stable path the wrapper execs:
# /app/extra/xlights. Its layout is the linuxdeploy standard — AppRun, an
# apprun-hooks/ directory, and usr/ holding the 72 MB xLights binary plus the
# 255 shared libraries it resolves through its own RUNPATH ($ORIGIN/../lib).
# AppRun is the AppImage format's entry point rather than a name upstream picks
# per release, so exec'ing it (instead of the binary) keeps the bundle's own
# launch logic — in particular apprun-hooks/linuxdeploy-plugin-gtk.sh, which
# points GTK at the bundled pixbuf loaders, IM modules and GSettings schemas.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f xlights.AppImage ]      || { echo "missing extra-data: xlights.AppImage" >&2; exit 1; }
[ -f appimage-tools.tar.xz ] || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine. Both the
# tarball below and unsquashfs (via -no-xattrs, and it never chowns) are safe
# under that constraint.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" xlights.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf xlights
# -no-xattrs: the apply_extra sandbox has all capabilities dropped and cannot
# set security xattrs; -d writes straight to the final path, no rename needed.
"$tools/unsquashfs" -no-xattrs -o "$offset" -d xlights xlights.AppImage

# AppRun.wrapped is linuxdeploy's symlink to the real binary; check both so a
# bundle that unpacked but lost its entry point fails here rather than at launch.
[ -x xlights/AppRun ]           || { echo "AppRun missing after unpack" >&2; exit 1; }
[ -x xlights/usr/bin/xLights ]  || { echo "xLights binary missing after unpack" >&2; exit 1; }

# Drop the 124 MB AppImage and the extractor now that the tree is staged —
# otherwise both sit on the user's disk for the life of the install.
rm -rf xlights.AppImage appimage-tools.tar.xz appimage-tools
