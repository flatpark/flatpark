#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Two files have
# already been fetched here by extra-data: upstream's AppImage and the two-tool
# stack that opens it. The vendor's bytes run unmodified - nothing is patched
# or recompiled, and the AppImage is never executed.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in revpdf.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf revpdf squashfs-root appimage-tools

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools_bin="$extra_root/appimage-tools/bin"
[ -x "$tools_bin/appimage-offset" ] && [ -x "$tools_bin/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

# A type-2 AppImage is an ELF stub with a SquashFS appended to it: ask where
# that starts, then unpack from the offset. No libfuse, no mounting.
offset="$("$tools_bin/appimage-offset" revpdf.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools_bin/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" revpdf.AppImage >/dev/null

# The AppDir is a stock Flutter bundle - revpdf_editor next to lib/ (engine,
# plugins, the app's AOT snapshot and the PDFium / Tesseract stack it carries)
# and data/ (flutter_assets, icudtl.dat) - and the engine finds data/ relative
# to the executable, so the three stay siblings and the tree moves as a whole.
[ -x squashfs-root/revpdf_editor ] || { echo "no revpdf_editor in the AppImage" >&2; exit 1; }
[ -d squashfs-root/lib ] && [ -d squashfs-root/data ] \
    || { echo "AppImage is not the expected Flutter bundle layout" >&2; exit 1; }
mv squashfs-root revpdf

rm -rf appimage-tools revpdf.AppImage appimage-tools.tar.xz
