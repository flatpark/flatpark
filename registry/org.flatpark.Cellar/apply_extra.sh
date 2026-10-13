#!/bin/sh
set -eu

# Runs offline at install time. The release asset is a single self-contained
# binary (GUI and CLI in one); stage it under the name /app/bin/cellar links to.

cd "${EXTRA_ROOT:-/app/extra}"

[ -f cellar-x86_64 ] || { echo "missing extra-data: cellar-x86_64" >&2; exit 1; }
mv cellar-x86_64 cellar
chmod +x cellar
