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
# The CJK font fetched next to it comes as the noto-fonts prebuilt stack and is
# unpacked into /app/extra/noto-fonts, whose share/fonts the app's fonts.conf
# lists, so CJK text and the Simplified Chinese and Korean UI
# translations render instead of tofu.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }

rm -rf stage dbflux
mkdir stage
# --no-same-owner is required because a system-wide apply_extra runs as root with
# every capability dropped and cannot restore archive ownership.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/dbflux ] || { echo "dbflux binary not found in .deb" >&2; exit 1; }
mv stage/usr/bin/dbflux dbflux
rm -rf stage app.deb

# The bundled Noto faces come as the noto-fonts prebuilt stack (extra-data
# too). Unpacking it leaves them in /app/extra/noto-fonts/share/fonts, the
# directory fonts.conf lists.
[ -f noto-fonts.tar.xz ] || { echo "missing extra-data: noto-fonts.tar.xz" >&2; exit 1; }
rm -rf noto-fonts
bsdtar --no-same-owner -xf noto-fonts.tar.xz
rm -f noto-fonts.tar.xz
[ -s noto-fonts/share/fonts/NotoSansCJK-Regular.ttc ] || { echo "NotoSansCJK-Regular.ttc not found in noto-fonts.tar.xz" >&2; exit 1; }
