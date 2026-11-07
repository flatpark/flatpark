#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f openwhispr.tar.gz ] || { echo 'missing extra-data: openwhispr.tar.gz' >&2; exit 1; }
rm -rf stage openwhispr
mkdir stage
# System installs run as root without capabilities: never restore archive owners.
bsdtar --no-same-owner -xf openwhispr.tar.gz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo 'expected one portable app directory' >&2; exit 1; }
mv "$1" openwhispr
# afterPack ships a shell launcher and its sibling *-app Electron executable.
# Resolve exactly one executable instead of assuming upstream's product name.
set -- openwhispr/*-app
[ "$#" -eq 1 ] && [ -x "$1" ] && [ -f openwhispr/resources/app.asar ] || {
    echo 'expected one Electron *-app executable and resources/app.asar' >&2; exit 1;
}
printf '%s\n' "${1##*/}" > launcher
# zypak supplies the Chromium sandbox; the unused SUID helper needs no setuid bit.
chmod -R a-s openwhispr
rm -rf stage openwhispr.tar.gz
