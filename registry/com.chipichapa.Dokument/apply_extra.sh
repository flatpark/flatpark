#!/bin/sh
set -eu

cd "${EXTRA_ROOT:-/app/extra}"
[ -f dokument.tar.gz ] || { echo 'Missing extra-data: dokument.tar.gz' >&2; exit 1; }
rm -rf dokument
mkdir dokument
# Flatpak system installs run this as root without chown capabilities.
tar --no-same-owner -xzf dokument.tar.gz -C dokument
[ -x dokument/bin/dokument ] && [ -x dokument/libexec/dokument-scan-worker ] \
    || { echo 'Dokument executable or scanner worker missing' >&2; exit 1; }
rm dokument.tar.gz
