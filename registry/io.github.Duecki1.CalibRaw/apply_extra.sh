#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# CalibRaw for Linux as an AppImage. A type-2 AppImage is an ELF stub with a
# SquashFS filesystem concatenated after it; it never has to be executed or
# FUSE-mounted to read it, the appended filesystem is unpacked directly.
#
# Two tools do that, both from the appimage-tools extra-data fetched alongside
# the AppImage:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset
#
# The result is the AppDir, a linuxdeploy tree staged whole at a stable path
# the wrapper execs: /app/extra/calibraw. The CalibRaw binary sits at its top
# with RUNPATH $ORIGIN/lib and bundled dependencies.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time  extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

# Determine which architecture we're running on
arch="$(uname -m)"
case "$arch" in
  x86_64) appimage_file="CalibRaw-x86_64.AppImage" ;;
  aarch64) appimage_file="CalibRaw-aarch64.AppImage" ;;
  *) echo "unsupported architecture: $arch" >&2; exit 1 ;;
esac

[ -f "$appimage_file" ] || { echo "missing extra-data: $appimage_file" >&2; exit 1; }
[ -f appimage-tools.tar.xz ]   || { echo "missing extra-data: appimage-tools.tar.xz" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine. Both the
# tarball below and unsquashfs (via -no-xattrs, and it never chowns) are safe
# under that constraint.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" "$appimage_file")"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf calibraw
# -no-xattrs: the apply_extra sandbox has all capabilities dropped and cannot
# set security xattrs; -d writes straight to the final path, no rename needed.
"$tools/unsquashfs" -no-xattrs -o "$offset" -d calibraw "$appimage_file"

# Find the actual binary - it should be in the AppDir
[ -d calibraw ] || { echo "calibraw directory not found after unpack" >&2; exit 1; }

# CalibRaw's AppImage has AppRun as the entry point
if [ -L calibraw/AppRun ]; then
  target="$(readlink calibraw/AppRun)"
  case "$target" in
    */*) echo "AppRun points outside the AppDir top level: $target" >&2; exit 1 ;;
  esac
  [ -x "calibraw/$target" ] || { echo "AppRun target '$target' not executable" >&2; exit 1; }
  ln -sf "$target" calibraw/launch
elif [ -x calibraw/AppRun ]; then
  # AppRun is the binary itself
  ln -sf AppRun calibraw/launch
else
  echo "No executable AppRun found in AppDir" >&2
  ls -la calibraw/ >&2
  exit 1
fi

# Drop the AppImage and the extractor now that the tree is staged  otherwise
# both sit on the user's disk for the life of the install.
rm -rf "$appimage_file" appimage-tools.tar.xz appimage-tools
