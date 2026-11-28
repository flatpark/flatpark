#!/bin/sh
set -eu

# Runs offline at install time. Two downloads from the same release of the
# developer's official builds:
#   ginrose.tar.gz  ginrose-<version>/ginrose (the launcher), its licence, and
#                   the menu entries, icons and metainfo the package ships
#                   itself at build time
#   rosemary        Ginrose's build of Rosemary: a plain executable
# The launcher goes to /app/extra/ginrose/ginrose and Rosemary to
# /app/extra/rosemary, fixed paths that the wrapper (/app/bin/ginrose) and the
# link (/app/bin/rosemary) made at build time point at. Ginrose's Flatpak mode
# runs the Rosemary at /app/bin/rosemary and nothing else.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in ginrose.tar.gz rosemary; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf stage ginrose
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf ginrose.tar.gz -C stage

# The top directory carries the version (ginrose-26.0.5.1); read it, don't
# hardcode it.
top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] || { echo "expected one top-level directory in ginrose.tar.gz" >&2; exit 1; }
mv "$top" ginrose
[ -x ginrose/ginrose ] || { echo "ginrose binary not found in ginrose.tar.gz" >&2; exit 1; }

# Extra-data files are not executable when Flatpak writes them.
chmod 755 rosemary

rm -rf stage ginrose.tar.gz
