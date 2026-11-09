#!/bin/sh
# Lacuna Web PKI, the program behind the Web PKI browser extension.
#
# Runs offline at install time, in the extension's extra/ folder, after
# Flatpak has downloaded the vendor's package and checked its sha256. Only
# the program is taken (one self-contained .NET file): not its native
# messaging manifests, which name /opt, nor its maintainer scripts.
set -eu
export LC_ALL=C

log() { echo "Web PKI apply_extra: $*" >&2; }

unpack_deb() { # deb dest
    mkdir -p "$2"
    bsdtar -xOf "$1" 'data.tar*' | bsdtar --no-same-owner -xf - -C "$2"
}

unpack_deb webpki.deb deb
[ -f deb/opt/lacuna-webpki/webpki ] || { log "the program is not in the package"; exit 1; }
mv deb/opt/lacuna-webpki/webpki webpki
rm -rf deb webpki.deb
chmod 755 webpki
test -x webpki
