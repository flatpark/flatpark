#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f bottom.tar.gz ] || { echo 'missing extra-data: bottom.tar.gz' >&2; exit 1; }
mkdir -p bottom
# System installs unpack without ownership-restoration capabilities.
bsdtar --no-same-owner -xf bottom.tar.gz -C bottom
[ -x bottom/btm ] || { echo 'bottom executable missing from upstream archive' >&2; exit 1; }
rm -f bottom.tar.gz
