#!/bin/sh
set -eu

# Opens PJe-Calc's page in the user's browser, through the OpenURI portal. The
# launcher and pjecalc.sh may both ask within the same second at start-up, so a
# request within a few seconds of the last one is dropped.

stamp=${XDG_RUNTIME_DIR:-/tmp}/pjecalc-browser
if [ -n "$(find "$stamp" -newermt '-5 seconds' 2>/dev/null)" ]; then
    exit 0
fi
touch "$stamp"
exec xdg-open "${1:?}"
