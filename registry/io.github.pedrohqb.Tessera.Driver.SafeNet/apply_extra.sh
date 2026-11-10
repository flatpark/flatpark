#!/bin/sh
# SafeNet Authentication Client (Thales), for SafeNet eToken 5100/5110 and
# IDPrime cards.
#
# Runs offline at install time, in the extension's extra/ folder, after
# Flatpak has downloaded the zip and checked its sha256. The zip is the one
# GlobalSign distributes for Ubuntu 24.04 (the same Thales packages, signed
# by Thales; the AUR's sac-core uses it too). It carries the full package
# and the "withoutUI" core one; only the core package is taken, the clean
# way: its files, no maintainer script, no /etc. The zip's folders are
# read-only (0555), so they are made writable before being removed.
set -eu
export LC_ALL=C

log() { echo "SafeNet apply_extra: $*" >&2; }

unpack_deb() { # deb dest
    mkdir -p "$2"
    bsdtar -xOf "$1" 'data.tar*' | bsdtar --no-same-owner -xf - -C "$2"
}

mkdir -p zip
bsdtar --no-same-owner -xf safenet.zip -C zip
deb=$(find zip -path '*withoutUI*' -name '*safenetauthenticationclient-core_*_amd64.deb' | sort | tail -n1)
[ -n "$deb" ] || { log "the core package is not in the zip"; exit 1; }
unpack_deb "$deb" .
chmod -R u+w zip
rm -rf zip safenet.zip etc
lib=$(find usr -name 'libeToken.so*' \( -type f -o -type l \) | sort | head -n1)
[ -n "$lib" ] || { log "libeToken.so not found in the package"; exit 1; }
ln -sf "$lib" libeToken.so
test -e libeToken.so
