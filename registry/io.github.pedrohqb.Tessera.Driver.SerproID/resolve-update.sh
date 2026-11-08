#!/usr/bin/env bash
# Update resolver for the SerproID driver extension of Tessera.
#
# The vendor publishes no machine-readable "latest release", and every new
# version of its driver is tested with Tessera before it is pinned. So this
# prints the pinned version and download(s), the same as the manifest's
# managed block (and as flatpak/extensions/SerproID in pedrohqb/tessera): a new
# version comes as a pull request that changes both.
#
# Prints:
#   { "version": "...", "sources": [ { "filename": "...", "url": "..." } ] }
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "missing command: jq" >&2; exit 1; }
echo "pinned SerproID 2.1.6" >&2
jq -n '{version:"2.1.6", sources:[{filename:"serproid.deb", url:"https://storagegw.estaleiro.serpro.gov.br/instalador-desktop/SerproID-2.1.6-amd64.deb"}]}'
