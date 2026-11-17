#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f mistralrs.tar.gz ] || { echo 'Missing extra-data: mistralrs.tar.gz' >&2; exit 1; }
rm -rf mistralrs
mkdir mistralrs
# System installs unpack as root with all capabilities dropped.
bsdtar --no-same-owner -xf mistralrs.tar.gz -C mistralrs
[ -x mistralrs/mistralrs ] || { echo 'Missing upstream executable: mistralrs' >&2; exit 1; }
rm mistralrs.tar.gz
