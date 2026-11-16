#!/usr/bin/env bash
# Update resolver for the ePass2003 (Feitian) driver extension of Tessera.
#
# The library is Feitian's EnterSafe Castle SDK for Linux of 2014-11-28, as
# Soluti (a Brazilian certificate authority) distributes it. There is no
# machine-readable "latest release", and a new version would be tested with
# Tessera before it is pinned. So this prints the pinned version and
# download, the same as the manifest's managed block (and as
# flatpak/extensions/ePass2003 in pedrohqb/tessera): a new version comes as a
# pull request that changes both.
#
# Prints:
#   { "version": "...", "sources": [ { "filename": "...", "url": "..." } ] }
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "missing command: jq" >&2; exit 1; }
echo "pinned Feitian EnterSafe Castle 20141128" >&2
jq -n '{version:"20141128", sources:[{filename:"epass2003.tar.gz", url:"https://site.solutinet.com.br/drivers/Token/ePass2003/Linux/ePass2003_Castle_20141128.tar.gz"}]}'
