#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f bloom.rpm ] || { echo 'missing bloom.rpm' >&2; exit 1; }
# A system install extracts as root without the capability to restore owners.
bsdtar --no-same-owner -xf bloom.rpm
[ -x usr/bin/bloom ] || { echo 'missing Bloom binary' >&2; exit 1; }
[ -f usr/share/glib-2.0/schemas/io.github.oatbiscuit.bloom.gschema.xml ] || { echo 'missing Bloom settings schema' >&2; exit 1; }
# The RPM ships the schema XML. Generate the cache from the installed version.
glib-compile-schemas usr/share/glib-2.0/schemas
rm bloom.rpm
