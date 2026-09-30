#!/bin/sh
set -eu

# Runs offline at install time. The upstream artifact is the official prebuilt
# install tree (usr/bin/grab + desktop, metainfo, icon, schemas, D-Bus service
# under usr/share), built inside the GNOME SDK — the same libc the Flatpak
# runtime ships. Unpack it and keep the tree at a stable path the wrapper
# execs; GTK/libadwaita resolve from the runtime. The desktop file, icon,
# AppStream metainfo, GSettings schema and D-Bus service are shipped by the
# manifest at *build* time (extra-data is fetched later on the user's machine,
# so anything Flatpak must export cannot come from here).
# The vendor's bytes run unmodified — nothing is patched or recompiled.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f grab.tar.gz ] || { echo "missing extra-data: grab.tar.gz" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
tar --no-same-owner -xzf grab.tar.gz
[ -x usr/bin/grab ] || { echo "binary not found in tarball" >&2; exit 1; }

rm -f grab.tar.gz
