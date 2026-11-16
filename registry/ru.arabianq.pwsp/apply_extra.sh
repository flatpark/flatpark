#!/bin/sh
set -eu

# Runs offline at install time. The official download is a zip holding three
# binaries and nothing else: pwsp-daemon, pwsp-gui and pwsp-cli. They link
# libpipewire, libasound and OpenSSL, which the freedesktop runtime provides.
# They are moved to a fixed directory the wrapper runs from. The desktop entry,
# icon and AppStream metainfo come from the manifest at build time, since
# extra-data only arrives on the user's machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f pwsp.zip ] || { echo "missing extra-data: pwsp.zip" >&2; exit 1; }

rm -rf stage pwsp
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and the zip records uid 1001, which it cannot restore.
bsdtar --no-same-owner -xf pwsp.zip -C stage

# Fail the update check, not the user, if upstream changes the layout.
for bin in pwsp-daemon pwsp-gui pwsp-cli; do
    [ -f "stage/$bin" ] || { echo "$bin not found in pwsp.zip" >&2; exit 1; }
done

mv stage pwsp
chmod +x pwsp/pwsp-daemon pwsp/pwsp-gui pwsp/pwsp-cli

rm -f pwsp.zip
