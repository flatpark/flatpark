#!/bin/sh
set -eu
# Flatpak runs this offline, as uid 0 with no capabilities on system installs.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f mujoco.tar.gz ] || { echo "missing extra-data: mujoco.tar.gz" >&2; exit 1; }
rm -rf stage mujoco
mkdir stage
bsdtar --no-same-owner -xf mujoco.tar.gz -C stage
# Discover the versioned root rather than pinning its name.
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one MuJoCo directory" >&2; exit 1; }
mv "$1" mujoco
[ -x mujoco/bin/simulate ] || { echo "MuJoCo simulate executable missing" >&2; exit 1; }
[ -f mujoco/model/welcome/welcome.xml ] || { echo "MuJoCo welcome model missing" >&2; exit 1; }
rm -rf stage mujoco.tar.gz
