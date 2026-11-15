#!/bin/sh
set -eu
# Flatpak runs this offline as root without capabilities on system installs.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f sd.zip ] || { echo "missing extra-data: sd.zip" >&2; exit 1; }
rm -rf stage stable-diffusion
mkdir stage
bsdtar --no-same-owner -xf sd.zip -C stage
# Upstream's portable archives contain the CLI, server and libraries at root.
for binary in sd-cli sd-server; do
    [ -x "stage/$binary" ] || { echo "missing executable: $binary" >&2; exit 1; }
done
[ -f stage/libstable-diffusion.so ] || { echo "missing stable-diffusion library" >&2; exit 1; }
mv stage stable-diffusion
rm sd.zip
