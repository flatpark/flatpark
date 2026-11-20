#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The upstream
# tarball is one versioned directory holding four programs side by side:
#
#   misterdownloadmanager         the window and download engine
#   misterdownloadmanager-nmhost  browser native-messaging helper (unused here)
#   misterdownloadmanager-cli     command-line client of the running app
#   misterdownloadmanager-mcp     Model Context Protocol server
#
# plus the browser extensions, LICENSE and ATTRIBUTION.md. Stage the whole
# directory at a stable path, /app/extra/mdm, so the wrapper works across
# updates whatever the version in the directory name.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# build time: extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f mdm.tar.gz ] || { echo "missing extra-data: mdm.tar.gz" >&2; exit 1; }

rm -rf stage mdm
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, and the tarball records uid 1001.
bsdtar --no-same-owner -xf mdm.tar.gz -C stage

# Exactly one top-level directory is expected; its name carries the version.
set -- stage/*/
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one top-level directory in mdm.tar.gz, found: $*" >&2; exit 1; }

for exe in misterdownloadmanager misterdownloadmanager-cli; do
  [ -x "$1$exe" ] || { echo "$exe not found in mdm.tar.gz" >&2; exit 1; }
done

mv "$1" mdm
rm -rf stage mdm.tar.gz
