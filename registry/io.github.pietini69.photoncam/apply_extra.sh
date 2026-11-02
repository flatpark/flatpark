#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# the official Linux build as a .tar.gz with one version-stamped top directory
# holding the binary and a .desktop file; the binary name is read from its Exec=
# (upstream renamed the project once) and linked to photoncam/photoncam, which
# the wrapper runs. The archive also carries Apple extended
# attributes; restoring them fails when apply_extra runs as root with every
# capability dropped.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=photoncam.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf photoncam staging
mkdir staging
bsdtar --no-same-owner --no-xattrs -xf "$archive" -C staging

set -- staging/*/
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one top-level folder in the tarball, found: $*" >&2; exit 1; }
top=${1%/}

bin=$(sed -n 's/^Exec=//p' "$top"/*.desktop 2>/dev/null | head -n1 | cut -d' ' -f1)
bin=${bin##*/}
[ -n "$bin" ] && [ -x "$top/$bin" ] || { echo "launcher from Exec= not found in the tarball: '$bin'" >&2; exit 1; }

mv "$top" photoncam
[ "$bin" = photoncam ] || ln -sf "$bin" photoncam/photoncam
rm -rf staging "$archive"
[ -x photoncam/photoncam ]
