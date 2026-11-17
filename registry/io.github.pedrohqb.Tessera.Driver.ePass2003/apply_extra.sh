#!/bin/sh
# Feitian's ePass2003 library (EnterSafe Castle SDK for Linux, 2014-11-28),
# for the ePass2003 formatted by Feitian's software.
#
# Runs offline at install time, in the extension's extra/ folder, after
# Flatpak has downloaded the archive and checked its sha256. The archive is
# the one Soluti, a Brazilian certificate authority, distributes for Linux.
# Only the 64-bit PKCS#11 library is kept: not the samples, the GTK 2 PIN
# manager, the Firefox and Thunderbird scripts, nor config.sh (which would
# open the token's USB device to every user; the system already gives it to
# the person at the computer).
set -eu
export LC_ALL=C

log() { echo "ePass2003 apply_extra: $*" >&2; }

mkdir -p pkg
bsdtar --no-same-owner -xf epass2003.tar.gz -C pkg
lib=$(find pkg -path '*x86_64/redist/libcastle.so.1.0.0' -type f | head -n1)
[ -n "$lib" ] || { log "libcastle.so.1.0.0 (x86_64) not in the archive"; exit 1; }
mv "$lib" libcastle.so.1.0.0
chmod 0644 libcastle.so.1.0.0
chmod -R u+w pkg
rm -rf pkg epass2003.tar.gz
test -f libcastle.so.1.0.0
