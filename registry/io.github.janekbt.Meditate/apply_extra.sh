#!/bin/sh
set -eu

# Runs offline at install time. The upstream artifact is the official app
# tree (meditate/bin/meditate, locales, compiled GSettings schema), built by
# upstream's Flatpak CI inside the GNOME SDK. GTK/libadwaita come from the
# runtime. The vendor's bytes run unmodified.

cd "${EXTRA_ROOT:-/app/extra}"

[ -f meditate.tar.gz ] || { echo "missing extra-data: meditate.tar.gz" >&2; exit 1; }

# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring recorded uid/gid would abort the unpack.
# Runs again on every update in the same /app/extra: drop the old tree first.
rm -rf meditate
tar --no-same-owner -xzf meditate.tar.gz
[ -x meditate/bin/meditate ] || { echo "binary not found in tarball" >&2; exit 1; }

rm -f meditate.tar.gz
