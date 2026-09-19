#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The payload is the
# complete /app tree built by CI in flatpark/bottles-release: Bottles itself, the
# bundled wine, vte, ImageMagick, yara, umu, fvs2 and the cp314 Python wheels.
#
# It cannot be unpacked to /app — while apply_extra runs, /app is read-only and
# only the working directory (/app/extra) is writable, and a Flatpak sandbox
# cannot start a nested bwrap to bind it back. So the tree stays at
# /app/extra/bottles and the shell manifest's symlinks and environment variables
# reconnect the paths. bottles-release already rewrote the RUNPATHs that
# hardcoded /app into $ORIGIN-relative ones, so the tree's linkage stays
# self-consistent after the move.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f bottles.tar.zst ] || { echo "missing extra-data: bottles.tar.zst" >&2; exit 1; }

rm -rf bottles
# The Platform's bsdtar is built with libzstd and reads .tar.zst directly.
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf bottles.tar.zst

[ -x bottles/bin/bottles ] || { echo "bottles launcher missing after unpack" >&2; exit 1; }
[ -x bottles/bin/wine ] || { echo "bundled wine missing after unpack" >&2; exit 1; }

rm -f bottles.tar.zst
