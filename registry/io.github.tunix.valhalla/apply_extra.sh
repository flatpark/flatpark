#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream
# artifact is the official portable build: one versioned top directory
# (valhalla-v<ver>/) holding the binary and its compiled GSettings schema —
# the app links GTK4/libadwaita/libsecret, all of which the GNOME runtime
# provides, and finds gschemas.compiled next to its own binary on its own.
# Rename the tree to a stable path so the wrapper can exec it across
# updates. The desktop file, icon and AppStream metainfo are shipped by the
# manifest at *build* time (extra-data is fetched later on the user's
# machine, so anything Flatpak must export cannot come from here).
# The vendor's bytes run unmodified — nothing is patched or recompiled.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f valhalla.tar.gz ] || { echo "missing extra-data: valhalla.tar.gz" >&2; exit 1; }

rm -rf stage valhalla
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# would abort the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf valhalla.tar.gz -C stage

top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] || { echo "expected one top-level directory in the tarball" >&2; exit 1; }
mv "$top" valhalla
[ -x valhalla/valhalla ] || { echo "valhalla binary not found in the tarball" >&2; exit 1; }
[ -f valhalla/gschemas.compiled ] || { echo "gschemas.compiled not found in the tarball" >&2; exit 1; }

rm -rf stage valhalla.tar.gz
