#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships XerahS
# for Linux as a self-contained .NET 10 tarball with a flat layout: the
# single-file XerahS apphost, the xerahs-watchfolder-daemon, Plugins/ (the upload
# destinations), frontend/ (the web UI) and Resources/. The app looks for
# Plugins/ and frontend/ beside the executable, so the tree is staged whole at
# /app/extra/xerahs, unmodified.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f xerahs.tar.gz ] || { echo "missing extra-data: xerahs.tar.gz" >&2; exit 1; }

rm -rf xerahs
mkdir xerahs
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf xerahs.tar.gz -C xerahs
rm -f xerahs.tar.gz

# The tarball does not carry the exec bit on the two apphosts; set it here
# (upstream's own Flatpak manifest does the same chmod).
[ -f xerahs/XerahS ] || { echo "XerahS missing after unpack" >&2; exit 1; }
chmod 755 xerahs/XerahS
[ -f xerahs/xerahs-watchfolder-daemon ] && chmod 755 xerahs/xerahs-watchfolder-daemon
[ -d xerahs/Plugins ] || { echo "Plugins/ missing after unpack" >&2; exit 1; }
