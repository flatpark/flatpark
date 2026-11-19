#!/bin/sh
set -eu

# Runs offline at install time. Upstream's portable Linux tarball holds one
# version-stamped top directory (prism-<version>/) with the Electron app, the
# native DSP addon, prism-tui and the DAW plugins. Unpack it and rename that
# directory to a stable path the wrappers exec. The desktop file, icon and
# metainfo are shipped by the manifest at build time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f prism.tar.gz ] || { echo "missing extra-data: prism.tar.gz" >&2; exit 1; }

rm -rf stage prism
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf prism.tar.gz -C stage

top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ -n "$top" ] && [ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] \
  || { echo "expected exactly one top-level directory in prism.tar.gz" >&2; exit 1; }
mv "$top" prism
[ -x prism/prism ] || { echo "prism binary not found in the tarball" >&2; exit 1; }
[ -x prism/resources/tui/prism-tui ] || { echo "prism-tui not found in the tarball" >&2; exit 1; }

# chrome-sandbox is unused under zypak; make sure no setuid bit survives.
chmod -R a-s prism

rm -rf stage prism.tar.gz
