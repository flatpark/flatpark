#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f ffmpeg-full.tar.xz ] || { echo 'missing ffmpeg-full.tar.xz' >&2; exit 1; }
bsdtar --no-same-owner -xf ffmpeg-full.tar.xz
for tool in ffmpeg ffprobe; do
    [ -x "ffmpeg-full/bin/$tool" ] || { echo "$tool missing from ffmpeg-full" >&2; exit 1; }
done
rm -f ffmpeg-full.tar.xz
