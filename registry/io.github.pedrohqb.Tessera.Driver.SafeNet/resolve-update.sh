#!/usr/bin/env bash
# Update resolver for the SafeNet Authentication Client driver extension of Tessera.
#
# The vendor publishes no machine-readable "latest release", and every new
# version of its driver is tested with Tessera before it is pinned. So this
# prints the pinned version and download(s), the same as the manifest's
# managed block (and as flatpak/extensions/SafeNet in pedrohqb/tessera): a new
# version comes as a pull request that changes both.
#
# Prints:
#   { "version": "...", "sources": [ { "filename": "...", "url": "..." } ] }
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "missing command: jq" >&2; exit 1; }
echo "pinned SafeNet Authentication Client 10.9" >&2
jq -n '{version:"10.9", sources:[{filename:"safenet.zip", url:"https://www.digicert.com/StaticFiles/Linux_SAC_10.9_GA.zip"}]}'
