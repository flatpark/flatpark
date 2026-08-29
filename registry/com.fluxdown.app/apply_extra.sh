#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload lives under /opt/fluxdown:
#
#   /opt/fluxdown/flux_down            the Flutter launcher (ELF)
#   /opt/fluxdown/lib/*.so             Flutter engine + plugins, RUNPATH $ORIGIN/lib
#   /opt/fluxdown/data/                flutter_assets, icudtl.dat, bundled fonts
#   /opt/fluxdown/fluxdown_nmh         browser native-messaging helper (unused here)
#   /opt/fluxdown/fluxdown_updater     self-updater (unused; Flatpak updates instead)
#
# Stage that whole tree at a stable path, /app/extra/fluxdown. Keeping the
# launcher, lib/ and data/ as siblings is load-bearing: the binary finds its
# plugins through its own RUNPATH ($ORIGIN/lib) and the Flutter embedder resolves
# data/flutter_assets relative to the executable, so flattening the tree would
# silently break asset and plugin loading.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f fluxdown.deb ] || { echo "missing extra-data: fluxdown.deb" >&2; exit 1; }

rm -rf stage fluxdown
mkdir stage
# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression — zstd here — is auto-detected).
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf fluxdown.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -d stage/opt/fluxdown ] || { echo "payload not found in .deb (opt/fluxdown)" >&2; exit 1; }

# Read the launcher name out of the artifact rather than hardcoding it: pin
# refreshes are automated, and the .deb's own desktop entry is the authoritative
# answer for what upstream called the binary.
exec_line="$(sed -n 's/^Exec=//p' stage/usr/share/applications/*.desktop | head -n1)"
launcher="${exec_line%% *}"
launcher="$(basename "$launcher")"
[ -x "stage/opt/fluxdown/$launcher" ] || { echo "launcher not found in .deb: $launcher" >&2; exit 1; }

mv stage/opt/fluxdown fluxdown
printf '%s\n' "$launcher" > fluxdown/.launcher

rm -rf stage fluxdown.deb
