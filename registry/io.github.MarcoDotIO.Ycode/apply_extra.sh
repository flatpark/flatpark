#!/bin/sh
set -eu

# Runs offline at install time. The tarball is Ycode's official Linux release:
# one versioned top directory (Ycode-<version>-<arch>) holding bin/, lib/ (the
# Swift runtime, SDL 3, libcurl and libxml2 it was built with), libexec/ and
# share/. Its programs find their libraries and helpers relative to themselves
# ($ORIGIN RUNPATHs), so the tree only needs a stable path for the wrapper.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ycode.tar.xz ] || { echo "missing extra-data: ycode.tar.xz" >&2; exit 1; }

rm -rf stage ycode
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf ycode.tar.xz -C stage

top="$(find stage -mindepth 1 -maxdepth 1 -type d -name 'Ycode-*')"
[ -n "$top" ] && [ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] ||
    { echo "expected one Ycode-* directory in the tarball" >&2; exit 1; }
mv "$top" ycode
[ -x ycode/bin/ycode-ide ] || { echo "ycode-ide not found in the tarball" >&2; exit 1; }

rm -rf stage ycode.tar.xz
