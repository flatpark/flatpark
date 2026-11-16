#!/bin/sh
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
archive=taobao-linux.tar.zst
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }
command -v zstd >/dev/null 2>&1 || { echo "missing zstd in runtime" >&2; exit 1; }
zstd -d --stdout "$archive" | tar --no-same-owner -xf -
[ -x electron/electron ] || { echo "Electron binary not found" >&2; exit 1; }
[ -f app.asar ] || { echo "app.asar not found" >&2; exit 1; }
[ -f app.asar.unpacked/node_modules/sqlite-vec-linux-x64/vec0.so ] || { echo "sqlite-vec Linux extension not found" >&2; exit 1; }
rm -f "$archive"
