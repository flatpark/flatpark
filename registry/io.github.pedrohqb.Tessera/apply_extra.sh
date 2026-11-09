#!/bin/sh
# Runs offline at install time, inside the runtime, after Flatpak has
# downloaded Tessera's release build (extra-data) and checked its size and
# sha256.
#
# Tessera's release build (tessera.tar.gz, the /app tree of Tessera's own
# Flatpak build) goes to /app/extra/tessera, unmodified. The vendors' token
# drivers are not here: each is an extension of its own
# (io.github.pedrohqb.Tessera.Driver.<Name>), installed by whoever needs it.
set -eu
# The install environment has no locale; without this every bsdtar call
# warns "Failed to set default locale".
export LC_ALL=C

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

log() { echo "tessera apply_extra: $*" >&2; }

[ -f tessera.tar.gz ] || { log "missing extra-data: tessera.tar.gz"; exit 1; }
rm -rf tessera tessera-stage
mkdir tessera-stage
bsdtar --no-same-owner -xf tessera.tar.gz -C tessera-stage || { log "could not unpack tessera.tar.gz"; exit 1; }
[ -d tessera-stage/tessera ] || { log "tessera/ missing from tessera.tar.gz"; exit 1; }
mv tessera-stage/tessera tessera
rm -rf tessera-stage tessera.tar.gz
# The app, the PC/SC library it bundles and its built-in driver, OpenSC.
for f in bin/tessera lib/libpcsclite.so.1 lib/opensc-pkcs11.so lib/tessera/drivers/opensc/driver.toml; do
    [ -e "tessera/$f" ] || { log "$f missing from tessera.tar.gz"; exit 1; }
done
# (The tree's desktop file and metainfo are not used: the package ships its
# own.)
