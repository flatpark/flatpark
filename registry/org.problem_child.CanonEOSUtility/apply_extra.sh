#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform.
#
# We ship a self-contained PyInstaller build (its own Python + PySide6 + Qt), so
# there is nothing to assemble here — just unpack it to a stable path that the
# wrapper execs: /app/extra/canon-eos-utility/canon-eos-utility.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f canon-eos-utility.tar.xz ] || { echo "missing extra-data: canon-eos-utility.tar.xz" >&2; exit 1; }

# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring an archive's recorded uid/gid would abort.
bsdtar --no-same-owner -xf canon-eos-utility.tar.xz

[ -x canon-eos-utility/canon-eos-utility ] || { echo "canon-eos-utility binary missing after unpack" >&2; exit 1; }

# Drop the download now that the tree is staged.
rm -f canon-eos-utility.tar.xz
