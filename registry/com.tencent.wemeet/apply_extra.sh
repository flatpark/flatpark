#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. WeMeet's official
# Debian package is a plain FHS tree rooted at opt/wemeet/. We unpack it whole and
# keep it under a stable path the wrapper expects: /app/extra/opt/wemeet/. The
# desktop file, icon and AppStream metainfo are shipped by the manifest at *build*
# time — extra-data is fetched later on the user's machine, so anything Flatpak
# must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f wemeet.deb ] || { echo "missing extra-data: wemeet.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the tree
# (inner data.tar compression is auto-detected).
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf wemeet.deb 'data.tar*' | bsdtar --no-same-owner -xf -
[ -x opt/wemeet/wemeetapp.sh ] || { echo "wemeetapp.sh not found in .deb" >&2; exit 1; }

# WeMeet reads a JSON screen-cast config from here; an empty object is the
# upstream-recommended default and avoids a first-run write to a read-only path.
echo '{}' > opt/wemeet/bin/xcast.conf

rm -f wemeet.deb
