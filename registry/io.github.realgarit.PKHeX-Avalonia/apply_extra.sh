#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# PKHeX-Avalonia for Linux as a flat zip: the self-contained single-file
# PKHeX.Avalonia apphost, the SkiaSharp and HarfBuzzSharp native libraries it
# loads from beside itself, debug symbols and a macOS icon. The tree is staged
# whole at /app/extra/pkhex, unmodified.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f pkhex-avalonia.zip ] || { echo "missing extra-data: pkhex-avalonia.zip" >&2; exit 1; }

rm -rf pkhex
mkdir pkhex
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf pkhex-avalonia.zip -C pkhex
rm -f pkhex-avalonia.zip

[ -f pkhex/PKHeX.Avalonia ] || { echo "PKHeX.Avalonia missing after unpack" >&2; exit 1; }
chmod 755 pkhex/PKHeX.Avalonia
[ -f pkhex/libSkiaSharp.so ] || { echo "libSkiaSharp.so missing after unpack" >&2; exit 1; }
