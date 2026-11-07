#!/bin/sh
set -eu

[ -f letters.tar.gz ] || { echo "missing extra-data: letters.tar.gz" >&2; exit 1; }

rm -rf letters
mkdir -p letters
bsdtar --no-same-owner -xf letters.tar.gz -C letters

[ -x letters/bin/letters ] || { echo "bin/letters missing after unpack" >&2; exit 1; }

rm -f letters.tar.gz
