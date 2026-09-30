#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Snipaste for Linux ONLY as an AppImage — no .deb, no .rpm, no plain tarball —
# so this repackages that. An AppImage is not a special format: a type-2 one is
# an ELF stub with a SquashFS filesystem concatenated after it. It never has to
# be executed or FUSE-mounted to read it; the appended filesystem is unpacked
# directly.
#
# Two tools do that, both from the appimage-tools extra-data fetched alongside
# the AppImage:
#   appimage-offset  prints the byte offset where the SquashFS begins
#   unsquashfs       unpacks from that offset
#
# The result is the AppDir, staged whole at a stable path the wrapper execs:
# /app/extra/snipaste. Its layout is a linuxdeploy AppRun plus usr/, where
# usr/bin holds the Snipaste binary, the wlhelper Wayland clipboard process and
# a qt.conf that points Qt at usr/plugins; usr/lib carries the vendor's Qt 6
# build and the rest of the bundle, reached through the binaries' own
# $ORIGIN/../lib runpath.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f snipaste.AppImage ]     || { echo "missing extra-data: snipaste.AppImage" >&2; exit 1; }
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

offset="$("$tools/appimage-offset" snipaste.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac

rm -rf snipaste
# -no-xattrs: the apply_extra sandbox has all capabilities dropped and cannot
# set security xattrs; -d writes straight to the final path, no rename needed.
"$tools/unsquashfs" -no-xattrs -o "$offset" -d snipaste snipaste.AppImage

# Which file is the launcher? The AppDir's own desktop entry says so in its
# Exec= line, and that is the name the wrapper must run. Reading it from the
# payload rather than hardcoding survives a rename: pin refreshes are
# automated, and a renamed binary would otherwise reach users as an app that
# installs and then cannot start.
desktop=""
for d in snipaste/*.desktop; do
    [ -f "$d" ] || continue
    desktop="$d"
    break
done
[ -n "$desktop" ] || { echo "no .desktop file at the AppDir root to resolve the launcher from" >&2; exit 1; }

launcher="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1)"
[ -n "$launcher" ] || { echo "no Exec= line in $desktop" >&2; exit 1; }
# Exec= in this AppDir is a bare command name, resolved against the AppDir's
# usr/bin by AppRun's PATH; reject anything else rather than run a path out of
# the payload.
case "$launcher" in
    */*) echo "unexpected Exec= path in $desktop: $launcher" >&2; exit 1 ;;
esac

[ -x "snipaste/usr/bin/$launcher" ] \
    || { echo "launcher '$launcher' from $desktop not executable in the AppDir" >&2; exit 1; }

# The wrapper reads the resolved binary from here rather than hardcoding it. It
# lives beside the app tree, not inside it, so the upstream tree stays exactly
# as shipped.
printf 'APP_BIN=%s\n' "$extra_root/snipaste/usr/bin/$launcher" > app.env

# Drop the AppImage and the extractor now that the tree is staged — otherwise
# both sit on the user's disk for the life of the install.
rm -rf snipaste.AppImage appimage-tools.tar.xz appimage-tools
