#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The payload is
# upstream's portable Linux tarball: one versioned top directory holding the
# viewer (open-3d-viewer), its MCP server (open-3d-viewer-mcp), and on x86_64
# only the Vertex BD reader it loads from beside itself (libvertex.so). Rename
# that directory to a stable path so the wrapper works across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f open-3d-viewer.tar.gz ] || { echo "missing extra-data: open-3d-viewer.tar.gz" >&2; exit 1; }

rm -rf stage open-3d-viewer
mkdir stage
# --no-same-owner: the tarball records uid 1001, and a system install runs
# this as root with every capability dropped.
bsdtar --no-same-owner -xf open-3d-viewer.tar.gz -C stage

# The top directory carries the version and arch; read it from the archive
# and fail if there is not exactly one.
set -- stage/*/
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one top directory in open-3d-viewer.tar.gz" >&2; exit 1; }
top="${1%/}"
[ -x "$top/open-3d-viewer" ] || { echo "open-3d-viewer not found in the tarball" >&2; exit 1; }
[ -x "$top/open-3d-viewer-mcp" ] || { echo "open-3d-viewer-mcp not found in the tarball" >&2; exit 1; }

mv "$top" open-3d-viewer
rm -f open-3d-viewer/README.md
rm -rf stage open-3d-viewer.tar.gz
