#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The payload is
# upstream's portable Linux tarball: one versioned top directory holding the
# app (open-pointcloud-studio), Open CAD Studio (OpenCADStudio), which the app
# starts from beside itself to show the DXF and DWG drawings it exports, and
# licence texts. Rename that directory to a stable path so the wrapper works
# across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f open-pointcloud-studio.tar.gz ] || { echo "missing extra-data: open-pointcloud-studio.tar.gz" >&2; exit 1; }

rm -rf stage open-pointcloud-studio
mkdir stage
# --no-same-owner: the tarball records uid 1001, and a system install runs
# this as root with every capability dropped.
bsdtar --no-same-owner -xf open-pointcloud-studio.tar.gz -C stage

# The top directory carries the version and arch; read it from the archive
# and fail if there is not exactly one.
set -- stage/*/
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one top directory in open-pointcloud-studio.tar.gz" >&2; exit 1; }
top="${1%/}"
[ -x "$top/open-pointcloud-studio" ] || { echo "open-pointcloud-studio not found in the tarball" >&2; exit 1; }
[ -x "$top/OpenCADStudio" ] || { echo "OpenCADStudio not found in the tarball" >&2; exit 1; }

mv "$top" open-pointcloud-studio
rm -rf stage open-pointcloud-studio.tar.gz
