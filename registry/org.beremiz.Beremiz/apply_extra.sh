#!/bin/sh
set -eu
# This archive is built from unmodified sources by beremiz-release.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f beremiz.tar.gz ] || { echo 'Missing beremiz.tar.gz extra-data' >&2; exit 1; }
rm -rf stage beremiz
mkdir stage
bsdtar --no-same-owner -xf beremiz.tar.gz -C stage
top=$(find stage -mindepth 1 -maxdepth 1 -type d)
[ "$(find stage -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ] && [ -n "$top" ] || {
    echo 'Expected one Beremiz payload directory' >&2; exit 1;
}
for entry in bin/beremiz bin/beremiz-cli bin/beremiz-runtime bin/beremiz-python matiec/iec2c toolchain/bin/gcc; do
    [ -x "$top/$entry" ] || { echo "Missing executable: $entry" >&2; exit 1; }
done
for entry in beremiz/Beremiz.py matiec/lib/ieclib.txt SOURCES.lock.json; do
    [ -f "$top/$entry" ] || { echo "Missing payload file: $entry" >&2; exit 1; }
done
mv "$top" beremiz
rm -rf stage beremiz.tar.gz
