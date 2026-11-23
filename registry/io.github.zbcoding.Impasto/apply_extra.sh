#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream artifact
# is the official self-contained .NET publish of Impasto: a flat zip (no
# top-level dir) with the native apphost launcher (Impasto), its bundled CoreCLR
# and the managed .dll assemblies, plus icons/ and locale/ trees. Unpack it to a
# stable path the wrapper execs: /app/extra/impasto. The desktop file, icon and
# AppStream metainfo are shipped by the manifest at *build* time — extra-data is
# fetched later on the user's machine, so anything Flatpak must export cannot
# come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f impasto.zip ] || { echo "missing extra-data: impasto.zip" >&2; exit 1; }

# The GNOME runtime has no unzip, but bsdtar (libarchive) reads zip directly.
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
rm -rf impasto
mkdir impasto
bsdtar --no-same-owner -xf impasto.zip -C impasto
[ -f impasto/Impasto.dll ] || { echo "Impasto.dll not found in zip" >&2; exit 1; }

# The publish zip does not carry the unix executable bit; the apphost launcher
# (and the createdump helper next to it) must be made executable.
chmod +x impasto/Impasto impasto/createdump 2>/dev/null || chmod +x impasto/Impasto
rm -f impasto.zip
