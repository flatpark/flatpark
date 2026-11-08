#!/bin/sh
set -eu

# Runs offline at install time and on every update, inside org.gnome.Platform,
# on the user's machine. Flatpak has put the pinned download here under the
# manifest's `filename`; unpack it to a stable path the wrapper execs.
#
# The tarball is upstream's portable build (make tarball): the pure-Python app,
# Markdown and Pygments vendored at its top level, plus style.css, the message
# catalog and the icon themes. Everything native comes from the runtime. The
# vendor's bytes run unmodified — nothing is patched or recompiled.
#
# The top-level directory carries the version, so it is matched by a pattern
# instead of a name: the updater re-pins the download and this script must keep
# working across versions.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f griffel.tar.gz ] || { echo "missing extra-data: griffel.tar.gz" >&2; exit 1; }

# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, so restoring the archive's recorded owner would fail and
# abort the unpack even though every member was written.
rm -rf griffel Griffel-*/
tar --no-same-owner -xzf griffel.tar.gz
rm -f griffel.tar.gz

set -- Griffel-*/
[ -d "$1" ] || { echo "payload directory not found in tarball" >&2; exit 1; }
mv "$1" griffel

[ -f griffel/griffel/__init__.py ] || { echo "app package missing after unpack" >&2; exit 1; }
[ -d griffel/vendor/markdown ] || { echo "vendored Markdown missing after unpack" >&2; exit 1; }
[ -d griffel/vendor/pygments ] || { echo "vendored Pygments missing after unpack" >&2; exit 1; }
