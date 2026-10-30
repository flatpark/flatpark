#!/bin/sh
set -eu
# Unpack the official portable Electron build offline, keeping its tree intact.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
[ -f tagspaces.tar.gz ] || { echo "missing extra-data: tagspaces.tar.gz" >&2; exit 1; }
rm -rf stage tagspaces
mkdir stage
# System installs run as root without capabilities: do not restore archive owners.
bsdtar --no-same-owner -xf tagspaces.tar.gz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one app directory" >&2; exit 1; }
mv "$1" tagspaces
# Locate the Electron executable by its ELF header, excluding bundled helpers
# and shared libraries. Store its name outside the vendor's tree for the wrapper.
launcher=""
for candidate in tagspaces/*; do
    [ -f "$candidate" ] && [ -x "$candidate" ] || continue
    case "${candidate##*/}" in chrome-sandbox|chrome_crashpad_handler|*.so|*.so.*) continue ;; esac
    magic="$(od -An -tx1 -N4 "$candidate" | tr -d ' \n')"
    [ "$magic" = 7f454c46 ] || continue
    [ -z "$launcher" ] || { echo "ambiguous Electron launcher" >&2; exit 1; }
    launcher="${candidate##*/}"
done
[ -n "$launcher" ] && [ -f tagspaces/resources/app.asar ] || { echo "Electron app missing in archive" >&2; exit 1; }
printf '%s\n' "$launcher" > launcher
# The setuid helper is unused under zypak.
chmod -R a-s tagspaces
rm -rf stage tagspaces.tar.gz
