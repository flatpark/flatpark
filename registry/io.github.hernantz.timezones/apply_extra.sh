#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Unpacks upstream's
# release tree, untouched, to /app/extra/timezones: the path it was built for.
# The desktop entry, metainfo and icon come from the manifest at build time,
# since Flatpak exports them before any extra-data exists.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f timezones.tar.xz ] || { echo "missing extra-data: timezones.tar.xz" >&2; exit 1; }

rm -rf timezones
mkdir timezones
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring the archive's uid/gid would fail.
bsdtar --no-same-owner -xf timezones.tar.xz -C timezones

# A tree missing any of these installs fine and then cannot start, or cannot
# search cities; fail the install instead.
for f in bin/timezones share/timezones/app.py lib/libgweather-4.so.0 \
         lib/girepository-1.0/GWeather-4.0.typelib \
         share/glib-2.0/schemas/gschemas.compiled; do
    [ -e "timezones/$f" ] || { echo "missing from the release tree: $f" >&2; exit 1; }
done

rm -f timezones.tar.xz
