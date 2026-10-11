#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# is a plain FHS tree whose payload is one self-contained binary, usr/bin/dbflux
# (drivers, themes, translations and the MCP server are all built into it).
# Keep only that binary, at the stable path the wrapper execs: /app/extra/dbflux.
#
# The CJK font fetched next to it is moved into /app/extra/fonts, which the
# app's fonts.conf lists, so CJK text and the Simplified Chinese and Korean UI
# translations render instead of tofu.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }
[ -f NotoSansCJK-Regular.ttc ] || { echo "missing extra-data: NotoSansCJK-Regular.ttc" >&2; exit 1; }

rm -rf stage dbflux fonts
mkdir stage
# --no-same-owner is required because a system-wide apply_extra runs as root with
# every capability dropped and cannot restore archive ownership.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/dbflux ] || { echo "dbflux binary not found in .deb" >&2; exit 1; }
mv stage/usr/bin/dbflux dbflux
rm -rf stage app.deb

mkdir fonts
mv NotoSansCJK-Regular.ttc fonts/NotoSansCJK-Regular.ttc
