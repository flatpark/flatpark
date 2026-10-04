#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# GoldenCheetah for Linux ONLY as an AppImage — no .deb, no .rpm, no tarball —
# so this repackages that. A type-2 AppImage is an ELF stub with a SquashFS
# filesystem concatenated after it; it never has to be executed or
# FUSE-mounted to read it, the appended filesystem is unpacked directly.
#
# Two tools do that, both from the appimage-tools extra-data fetched alongside
# the AppImage:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset
#
# The result is the AppDir, a linuxdeployqt tree staged whole at a stable path
# the wrapper execs: /app/extra/goldencheetah. The GoldenCheetah binary sits at
# its top with RUNPATH $ORIGIN/lib, a qt.conf pointing Qt at the bundled
# plugins, libexec/QtWebEngineProcess, and the relocatable Python 3.11 under
# usr/ and opt/ that the Python charts use. AppRun is a symlink to the binary.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f goldencheetah.AppImage ] || { echo "missing extra-data: goldencheetah.AppImage" >&2; exit 1; }
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

offset="$("$tools/appimage-offset" goldencheetah.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf goldencheetah
# -no-xattrs: the apply_extra sandbox has all capabilities dropped and cannot
# set security xattrs; -d writes straight to the final path, no rename needed.
"$tools/unsquashfs" -no-xattrs -o "$offset" -d goldencheetah goldencheetah.AppImage

# AppRun is the AppDir's entry point and links to the real binary; resolve the
# binary from it rather than hardcoding its name, and give the wrapper a fixed
# `launch` link to exec.
[ -L goldencheetah/AppRun ] || { echo "AppRun is not a symlink to the binary" >&2; exit 1; }
target="$(readlink goldencheetah/AppRun)"
case "$target" in
    */*) echo "AppRun points outside the AppDir top level: $target" >&2; exit 1 ;;
esac
[ -x "goldencheetah/$target" ] || { echo "AppRun target '$target' not executable" >&2; exit 1; }
[ -f goldencheetah/qt.conf ] || { echo "qt.conf missing after unpack" >&2; exit 1; }
ln -sf "$target" goldencheetah/launch

# Drop the AppImage and the extractor now that the tree is staged — otherwise
# both sit on the user's disk for the life of the install.
rm -rf goldencheetah.AppImage appimage-tools.tar.xz appimage-tools
