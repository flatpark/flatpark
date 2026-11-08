#!/usr/bin/env bash
# Update resolver for the SafeSign IC driver extension of Tessera.
#
# The vendor publishes no machine-readable "latest release", and every new
# version of its driver is tested with Tessera before it is pinned. So this
# prints the pinned version and download(s), the same as the manifest's
# managed block (and as flatpak/extensions/SafeSign in pedrohqb/tessera): a new
# version comes as a pull request that changes both.
#
# Prints:
#   { "version": "...", "sources": [ { "filename": "...", "url": "..." } ] }
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "missing command: jq" >&2; exit 1; }
echo "pinned SafeSign IC 4.5.0.0" >&2
jq -n '{version:"4.5.0.0", sources:[{filename:"safesign.deb", url:"https://assets.ctfassets.net/zuadwp3l2xby/6vGICRnQgQ8TkcHTgcouIr/5acf96dcbc0364aa9228606d3969ef97/SafeSignICStandardLinux4.5.0.0-AET.000ub2404x86_64.deb"},{filename:"safesign.rpm", url:"https://assets.ctfassets.net/zuadwp3l2xby/3b4YS8ts1cuD4BnUoQGZXl/93f644f03cc226b2adab290be11c6cd5/SafeSignICStandardLinux4.5.0.0-AET.000redhat10x86_64.rpm"},{filename:"gdbm.deb", url:"https://archive.ubuntu.com/ubuntu/pool/main/g/gdbm/libgdbm6t64_1.23-5.1build1_amd64.deb"},{filename:"gdbm-compat.deb", url:"https://archive.ubuntu.com/ubuntu/pool/main/g/gdbm/libgdbm-compat4t64_1.23-5.1build1_amd64.deb"}]}'
