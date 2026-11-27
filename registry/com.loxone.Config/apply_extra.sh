#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
test -s cellar-cli-x86_64
bsdtar --no-same-owner -xOf loxone-config.zip LoxoneConfigSetup.exe > LoxoneConfigSetup.exe
test -s LoxoneConfigSetup.exe
rm loxone-config.zip
mv cellar-cli-x86_64 cellar
chmod +x cellar
