#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Google's .deb
# keeps the browser under opt/google/chrome; only that directory is kept, at a
# stable path. The rest of the package (the apt cron job, the desktop entries,
# the man page) has no use inside the sandbox.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f chrome.deb ] || { echo "missing extra-data: chrome.deb" >&2; exit 1; }

rm -rf stage chrome
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with no capabilities.
bsdtar -xOf chrome.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage ./opt/google/chrome
[ -x stage/opt/google/chrome/chrome ] || { echo "chrome binary not found in .deb" >&2; exit 1; }

mv stage/opt/google/chrome chrome
# chrome-sandbox is recorded setuid root; zypak replaces it, and a system
# install must not leave a setuid file behind.
chmod -R a-s chrome
rm -rf stage chrome.deb
