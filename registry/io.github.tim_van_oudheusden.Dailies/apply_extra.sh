#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Unpacks upstream's
# release tree, untouched, to /app/extra/dailies: the path it was built for.
# The desktop entry, D-Bus service, metainfo and icon come from the manifest at
# build time, since Flatpak exports them before any extra-data exists.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f dailies.tar.xz ] || { echo "missing extra-data: dailies.tar.xz" >&2; exit 1; }

rm -rf dailies
mkdir dailies
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring the archive's uid/gid would fail.
bsdtar --no-same-owner -xf dailies.tar.xz -C dailies

# A tree missing any of these installs fine and then cannot start; fail the
# install instead. Upstream's build checks the same list before publishing.
for f in bin/dailies share/dailies/dailies/config.py \
         share/dailies/dailies.gresource \
         share/glib-2.0/schemas/gschemas.compiled; do
    [ -e "dailies/$f" ] || { echo "missing from the release tree: $f" >&2; exit 1; }
done

rm -f dailies.tar.xz
