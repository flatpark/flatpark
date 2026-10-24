#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# the Linux build as an electron-builder tarball with one version-stamped
# top-level directory (splayer-next-<version>-<x64|arm64>) holding the launcher,
# Chromium, the Rust native modules and app.asar. Unpack it and rename that
# directory to a stable path the wrapper execs. Everything the app needs at
# runtime is inside; the system GTK3/NSS/CUPS/X11/audio stack comes from the
# runtime. The desktop file, icon and AppStream metainfo are shipped by the
# manifest at build time — extra-data is fetched later on the user's machine, so
# anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f splayer-next.tar.gz ] || { echo "missing extra-data: splayer-next.tar.gz" >&2; exit 1; }

# Unpack into a staging directory, then move the one tree we want into place.
# Don't trust the archive's top-level name: it carries the version and the
# architecture, both of which upstream can change on an automated pin refresh.
rm -rf stage app
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf splayer-next.tar.gz -C stage

top=""
for d in stage/splayer-next-*/; do
    [ -d "$d" ] || continue
    [ -z "$top" ] || { echo "expected one top-level directory in the tarball, found more" >&2; exit 1; }
    top="${d%/}"
done
[ -n "$top" ] || { echo "expected an splayer-next-* directory in the tarball" >&2; exit 1; }

mv "$top" app
# Upstream keeps the launcher's name (electron-builder executableName) stable
# across releases; fail the install if that ever stops being true instead of
# shipping a wrapper that points at nothing.
[ -x app/SPlayer-Next ] || { echo "SPlayer-Next launcher not found in the tarball" >&2; exit 1; }
[ -f app/resources/app.asar ] || { echo "resources/app.asar missing in the tarball" >&2; exit 1; }

rm -rf stage splayer-next.tar.gz
