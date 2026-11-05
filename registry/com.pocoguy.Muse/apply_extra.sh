#!/bin/sh
set -eu
cd /app/extra

# Keep upstream's tarball unchanged; the UI resources are embedded in the binary.
bsdtar --no-same-owner -xf mixtapes.tar.zst
[ -x usr/bin/mixtapes ] || { echo "Mixtapes binary missing from archive" >&2; exit 1; }

# Only Node's executable is needed, not npm, headers or development files.
mkdir -p helpers
bsdtar --no-same-owner --strip-components=2 -xf node.tar.xz -C helpers '*/bin/node'
[ -x helpers/node ] || { echo "Node binary missing from archive" >&2; exit 1; }
mv yt-dlp_linux helpers/yt-dlp
chmod 755 helpers/yt-dlp
rm -f mixtapes.tar.zst node.tar.xz
