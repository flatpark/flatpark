#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
for f in usimmics.zip cellar-cli-x86_64; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
mkdir unpack
bsdtar -xf usimmics.zip -C unpack --no-same-owner
[ -f unpack/uSimmics/bin/uSimmics.exe ] || { echo "missing uSimmics executable" >&2; exit 1; }
mv unpack/uSimmics cellar-install
rmdir unpack
rm usimmics.zip
mv cellar-cli-x86_64 cellar
chmod +x cellar
