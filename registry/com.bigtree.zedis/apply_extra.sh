#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# is a plain FHS tree whose payload is one self-contained binary, usr/bin/zedis
# (themes, highlights and icons are embedded in it). Keep only that binary, at
# the stable path the wrapper execs: /app/extra/zedis.
#
# The CJK font fetched next to it is moved into /app/extra/fonts, which the
# app's fonts.conf lists, so CJK keys and values render instead of tofu.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }
[ -f NotoSansCJK-Regular.ttc ] || { echo "missing extra-data: NotoSansCJK-Regular.ttc" >&2; exit 1; }

rm -rf stage zedis fonts
mkdir stage
# --no-same-owner is required because a system-wide apply_extra runs as root with
# every capability dropped and cannot restore archive ownership.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/zedis ] || { echo "zedis binary not found in .deb" >&2; exit 1; }
mv stage/usr/bin/zedis zedis
rm -rf stage app.deb

mkdir fonts
mv NotoSansCJK-Regular.ttc fonts/NotoSansCJK-Regular.ttc
