#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
for f in cellar-cli-x86_64 7zip.exe; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
mv cellar-cli-x86_64 cellar
chmod +x cellar
