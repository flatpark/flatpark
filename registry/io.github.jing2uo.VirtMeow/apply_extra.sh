#!/bin/sh
set -eu

# Runs offline at install time. The release asset is a single self-contained
# binary (GUI and CLI in one), named the same on both arches; stage it under
# the name /app/bin/virt-mm links to.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f virt-meow-linux ] || { echo "missing extra-data: virt-meow-linux" >&2; exit 1; }
mv virt-meow-linux virt-mm
chmod +x virt-mm
