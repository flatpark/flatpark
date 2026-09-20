#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose only payload is a single self-contained
# Tauri binary under usr/bin (its web assets are embedded in the executable —
# there is no vendored lib/ tree). We stage just that binary at a stable path
# the wrapper execs: /app/extra/helixnotes/helixnotes. The desktop file, icon
# and AppStream metainfo are shipped by the manifest at *build* time —
# extra-data is fetched later on the user's machine, so anything Flatpak must
# export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f helixnotes.deb ] || { echo "missing extra-data: helixnotes.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage helixnotes
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf helixnotes.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The executable is named after the Debian package, which is upstream's to
# change; locate it by globbing usr/bin rather than hardcoding the name, so a
# rename cannot reach users as a failed install through an automated pin
# refresh (com.tldraw.Offline hit exactly that, issue #130).
binary=""
for f in stage/usr/bin/*; do
    [ -f "$f" ] && [ -x "$f" ] || continue
    binary="$f"
    break
done
[ -n "$binary" ] || { echo "no executable in the .deb's usr/bin" >&2; exit 1; }

mkdir helixnotes
mv "$binary" helixnotes/helixnotes
rm -rf stage helixnotes.deb
chmod +x helixnotes/helixnotes
