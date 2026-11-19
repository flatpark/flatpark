#!/bin/sh
set -eu

# Runs offline at install time inside org.kde.Platform. The archive is the /app
# tree of upstream's own Flatpak build on the same runtime, already trimmed to
# what the app needs: bin/ holds corvus, corvus-cli and qrencode, lib/ the
# qtkeychain and hunspell it links against, and share/hunspell the spell-check
# dictionaries, which corvus finds through <bin>/../share/hunspell. It is
# unpacked as is.

cd "${EXTRA_ROOT:-/app/extra}"

[ -f corvus.tar.gz ] || { echo "missing extra-data: corvus.tar.gz" >&2; exit 1; }

rm -rf corvus
mkdir corvus
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf corvus.tar.gz -C corvus

for f in corvus corvus-cli qrencode; do
  [ -x "corvus/bin/$f" ] || { echo "bin/$f not found in the archive" >&2; exit 1; }
done

rm -f corvus.tar.gz
