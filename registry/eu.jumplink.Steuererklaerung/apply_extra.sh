#!/bin/sh
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.tar.gz ] || { echo "missing extra-data: app.tar.gz" >&2; exit 1; }

rm -rf stage app
mkdir stage
bsdtar --no-same-owner -xf app.tar.gz -C stage

top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] || { echo "expected one top-level directory" >&2; exit 1; }
mv "$top" app
[ -x app/bin/steuererklaerung ] || { echo "steuererklaerung launcher not found in the tarball" >&2; exit 1; }

rm -rf stage app.tar.gz
