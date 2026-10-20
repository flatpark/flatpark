#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# AppImage and the two-tool stack that opens it have been fetched here by
# extra-data. The AppImage is never executed: its appended SquashFS is unpacked
# and the AppDir kept whole at /app/extra/omaphoto, where the binary finds its
# libraries through RUNPATH ($ORIGIN/../lib) and its Qt plugins through
# usr/bin/qt.conf, both of which need usr/bin, usr/lib and usr/plugins to stay
# siblings.
#
# The desktop file, icon, MIME data and metainfo are shipped by the manifest at
# build time; nothing Flatpak exports can come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in omaphoto.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
rm -rf omaphoto squashfs-root appimage-tools

# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring recorded owners would abort the unpack.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools=appimage-tools/bin

offset="$("$tools/appimage-offset" omaphoto.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -q -no-xattrs -d squashfs-root -o "$offset" omaphoto.AppImage >/dev/null

[ -x squashfs-root/usr/bin/omaphoto ] || { echo "no usr/bin/omaphoto in the AppImage" >&2; exit 1; }
mv squashfs-root omaphoto
rm -rf appimage-tools omaphoto.AppImage appimage-tools.tar.xz
