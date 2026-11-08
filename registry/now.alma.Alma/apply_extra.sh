#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships Alma as
# a .deb with the whole app under /opt/alma: the native Go launcher (it dlopens
# GTK 3 and WebKitGTK 4.1 from the runtime) and alma-server, a self-contained
# Node tree with its own runtime, native modules and bundled CLI tools. Since
# 0.4.491 it is no longer Electron; /opt/Alma survives only as a compatibility
# symlink to /opt/alma/alma and is not kept. Unpack the .deb's data member and
# keep just the app directory at a stable path the wrapper execs:
# /app/extra/alma. The desktop file, icon and AppStream metainfo are shipped by
# the manifest at *build* time — extra-data is fetched later on the user's
# machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f alma.deb ] || { echo "missing extra-data: alma.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage alma
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf alma.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/alma/alma ] || { echo "Alma binary not found in .deb" >&2; exit 1; }
[ -x stage/opt/alma/alma-server/runtime/alma-server ] || { echo "alma-server runtime not found in .deb" >&2; exit 1; }
mv stage/opt/alma alma
rm -rf stage alma.deb
[ -x alma/alma ] || { echo "Alma binary missing after stage" >&2; exit 1; }
