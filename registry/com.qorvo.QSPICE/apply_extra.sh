#!/bin/sh
set -eu

# Stage Cellar offline. The official downloader runs interactively later.
cd "${EXTRA_ROOT:-/app/extra}"
for file in cellar-cli-x86_64 InstallQSPICE.exe; do
    [ -s "$file" ] || { echo "missing extra-data: $file" >&2; exit 1; }
done
mv cellar-cli-x86_64 cellar
chmod +x cellar
