#!/bin/sh
set -eu
# Unpack official downloads offline; never restore archive ownership because
# system-wide installs run as root with every capability dropped.
cd "${EXTRA_ROOT:-/app/extra}"
for file in itksnap.tar.gz libssh-4.deb krb5-gss.tar.xz; do
    [ -f "$file" ] || { echo "missing extra-data: $file" >&2; exit 1; }
done
rm -rf stage itksnap support krb5-gss
mkdir stage
bsdtar --no-same-owner -xf itksnap.tar.gz -C stage
set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one portable application directory" >&2; exit 1; }
mv "$1" itksnap
[ -x itksnap/bin/itksnap ] || { echo "ITK-SNAP launcher missing" >&2; exit 1; }
set -- itksnap/lib/snap-*/ITK-SNAP
[ "$#" -eq 1 ] && [ -x "$1" ] || { echo "expected one ITK-SNAP executable" >&2; exit 1; }
mkdir -p stage/deb support krb5-gss
bsdtar --no-same-owner -xf libssh-4.deb -C stage/deb
set -- stage/deb/data.tar.*
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "Debian data archive missing" >&2; exit 1; }
bsdtar --no-same-owner -xf "$1" -C support
[ -f support/usr/lib/x86_64-linux-gnu/libssh.so.4 ] || { echo "libssh missing" >&2; exit 1; }
bsdtar --no-same-owner --strip-components=1 -xf krb5-gss.tar.xz -C krb5-gss
[ -f krb5-gss/lib/libgssapi_krb5.so.2 ] || { echo "GSSAPI library missing" >&2; exit 1; }
rm -rf stage itksnap.tar.gz libssh-4.deb krb5-gss.tar.xz
