#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# carries four self-contained binaries in usr/bin (openlogi, openlogi-desktop,
# openlogi-agent, openlogi-overlay) and the udev rules in etc/udev/rules.d.
# Keep the binaries together, unmodified, at /app/extra/openlogi: the GUI looks
# for the agent beside its own executable. The rules go next to them so the
# app's own "install the rules on the host" command can read them.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f openlogi.deb ] || { echo "missing extra-data: openlogi.deb" >&2; exit 1; }

rm -rf stage openlogi
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with no capabilities.
bsdtar -xOf openlogi.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

for bin in openlogi openlogi-desktop openlogi-agent openlogi-overlay; do
  [ -x "stage/usr/bin/$bin" ] || { echo "usr/bin/$bin not found in openlogi.deb" >&2; exit 1; }
done
[ -f stage/etc/udev/rules.d/70-openlogi.rules ] \
  || { echo "etc/udev/rules.d/70-openlogi.rules not found in openlogi.deb" >&2; exit 1; }

mv stage/usr/bin openlogi
mv stage/etc/udev/rules.d/70-openlogi.rules openlogi/70-openlogi.rules
rm -rf stage openlogi.deb
