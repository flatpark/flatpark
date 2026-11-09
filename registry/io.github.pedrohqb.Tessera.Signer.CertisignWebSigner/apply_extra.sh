#!/bin/sh
# Certisign WebSigner, the program behind the Certisign WebSigner browser
# extension (signing portals that use Certisign's plugin).
#
# Runs offline at install time, in the extension's extra/ folder, after
# Flatpak has downloaded the vendor's package and checked its sha256. Only
# the program and its dialogs (res/) are taken: not its native messaging
# manifests, which name /opt, nor its maintainer scripts.
#
# The program opens its dialogs at a fixed place,
# /opt/certisign-websigner/res/<name>.glade, which a browser's sandbox does
# not have. Each of those paths in the binary is overwritten in place with
# res/<name>.glade and a NUL (shorter, so nothing moves), and the start
# script runs the program from this folder.
set -eu
export LC_ALL=C

log() { echo "Certisign WebSigner apply_extra: $*" >&2; }

unpack_deb() { # deb dest
    mkdir -p "$2"
    bsdtar -xOf "$1" 'data.tar*' | bsdtar --no-same-owner -xf - -C "$2"
}

unpack_deb cswebsigner.deb deb
src=deb/opt/certisign-websigner
[ -f "$src/cswebsigner" ] && [ -d "$src/res" ] || { log "the program is not in the package"; exit 1; }
mv "$src/cswebsigner" "$src/res" .
rm -rf deb cswebsigner.deb

old='/opt/certisign-websigner/res/[a-z_0-9]+\.glade'
grep -obUaE "$old" cswebsigner | while IFS=: read -r offset path; do
    printf 'res/%s\000' "${path##*/}" | dd of=cswebsigner bs=1 seek="$offset" conv=notrunc 2>/dev/null
done
if grep -qaE "$old" cswebsigner; then
    log "a dialog path was left unchanged"
    exit 1
fi
names=$(grep -oaE 'res/[a-z_0-9]+\.glade' cswebsigner | sort -u)
[ -n "$names" ] || { log "no dialog path found in the program"; exit 1; }
for f in $names; do
    [ -f "$f" ] || { log "$f is missing"; exit 1; }
done
chmod 755 cswebsigner
test -x cswebsigner
