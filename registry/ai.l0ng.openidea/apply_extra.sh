#!/bin/sh
set -eu
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
[ -f openidea.deb ] || { echo "missing extra-data: openidea.deb" >&2; exit 1; }
rm -rf stage openidea
mkdir stage
# Match system installs, which unpack as root with no capabilities.
bsdtar -xOf openidea.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
# The upstream desktop entry identifies the executable across release renames.
set -- stage/usr/share/applications/*.desktop
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "expected one upstream desktop entry" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=\([^ %]*\).*/\1/p' "$1")"
case "$launcher" in ''|*/*) echo "unexpected upstream launcher: $launcher" >&2; exit 1 ;; esac
[ -x "stage/usr/bin/$launcher" ] || { echo "OpenIDEA executable missing: $launcher" >&2; exit 1; }
mkdir openidea
mv stage/usr openidea/usr
# Tauri uses the executable name as its Linux window class.
ln -s "usr/bin/$launcher" openidea/ai.l0ng.openidea
rm -rf stage openidea.deb

# Support tools are separate pinned downloads; upstream's app stays untouched.
rm -rf support
mkdir support
for archive in git.deb libcurl3t64-gnutls.deb librtmp1.deb libssh2-1t64.deb libnettle8t64.deb libhogweed6t64.deb libldap2.deb libsasl2-2.deb; do
    [ -f "$archive" ] || { echo "missing support download: $archive" >&2; exit 1; }
    bsdtar -xOf "$archive" 'data.tar*' | bsdtar --no-same-owner -xf - -C support
    rm -f "$archive"
done
[ -x support/usr/bin/git ] || { echo "Git executable missing" >&2; exit 1; }
mkdir stage
bsdtar --no-same-owner -xf uv.tar.gz -C stage
set -- stage/uv-*/uv
[ "$#" -eq 1 ] && [ -x "$1" ] || { echo "uv executable missing" >&2; exit 1; }
mv "$1" support/uv
rm -rf stage uv.tar.gz
# Keep only Git's runtime files, not documentation or exported desktop files.
rm -rf support/usr/share/doc support/usr/share/man support/usr/share/bash-completion support/usr/share/lintian
