#!/bin/sh
set -eu

# Runs offline at install time inside org.kde.Platform. The archive is
# site-packages/ from Handset's own Flatpak build on the same runtime: the
# handset and jeepney packages, and the PySide6 modules Handset uses, built
# against the runtime's Qt. It is unpacked as is.

cd "${EXTRA_ROOT:-/app/extra}"

[ -f handset.tar.gz ] || { echo "missing extra-data: handset.tar.gz" >&2; exit 1; }

rm -rf handset
mkdir handset
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf handset.tar.gz -C handset

for d in handset PySide6 shiboken6 jeepney; do
  [ -d "handset/site-packages/$d" ] || { echo "site-packages/$d not found in the archive" >&2; exit 1; }
done

rm -f handset.tar.gz
