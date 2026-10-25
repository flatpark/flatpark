#!/bin/sh
set -eu

# Runs offline at install time. Stages cellar's static CLI, the launcher every
# Wine package shares, under the name /app/bin/cellar links to. The vendor's
# installer stays as downloaded: cellar runs it in the user's own Wine prefix
# on first launch (cellar.toml, [install] method = "run").

cd "${EXTRA_ROOT:-/app/extra}"

for f in cellar-cli-x86_64 LTspice64.msi; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
mv cellar-cli-x86_64 cellar
chmod +x cellar
