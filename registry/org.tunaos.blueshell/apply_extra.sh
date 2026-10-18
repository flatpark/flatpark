#!/bin/sh
set -eu

# Runs offline at install time. Blueshell's Linux download is a tarball of
# the prebuilt /app tree its own Flatpak CI exports — the same files the
# vendor's .flatpak bundle and OCI image ship. It is unpacked, never
# executed; the tree lands at /app/extra/blueshell and the wrapper runs the
# vendor's own ghostty binary from it.
#
# The desktop file, icon and AppStream metainfo are installed by the
# manifest at build time, since extra-data only arrives on the user's
# machine.

[ -f blueshell.tar.gz ] || { echo "missing extra-data: blueshell.tar.gz" >&2; exit 1; }

rm -rf blueshell
mkdir -p blueshell
# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring recorded owners would fail.
bsdtar --no-same-owner -xf blueshell.tar.gz -C blueshell

[ -x blueshell/bin/ghostty ]                          || { echo "bin/ghostty missing after unpack" >&2; exit 1; }
[ -x blueshell/libexec/ptyxis-agent ]                 || { echo "libexec/ptyxis-agent missing after unpack" >&2; exit 1; }
[ -d blueshell/share/ghostty ]                        || { echo "share/ghostty missing after unpack" >&2; exit 1; }
[ -f blueshell/share/applications/org.tunaos.BlueShell.desktop ] || { echo "desktop file missing after unpack" >&2; exit 1; }

rm -f blueshell.tar.gz
