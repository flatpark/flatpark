#!/usr/bin/env bash
# Update resolver for the Certisign WebSigner extension of Tessera.
#
# The vendor's server sends its current package whatever version the URL
# names, and keeps no older ones, so the newest version is read from the
# package itself: a .deb is an ar archive whose control.tar, near its start,
# holds the Version. Only the first 64 KiB are fetched (a Range request; if
# the server ignores it, the rest of the transfer is cut off), and nothing is
# hashed here. The URL stays the one pinned: its path names the plugin's
# release (2.17.7), not the program's version (2.9.5 in it).
#
# Prints:
#   { "version": "...", "sources": [ { "filename": "cswebsigner.deb", "url": "..." } ] }
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq; need python3; need tar

probe="https://get.websignerplugin.com/Downloads/2.17.7/setup-deb-64"
version="$({ curl -fsSL -r 0-65535 "$probe" || true; } | head -c 65536 | python3 -I -c '
import subprocess, sys, tempfile
data = sys.stdin.buffer.read()
if data[:8] != b"!<arch>\n":
    sys.exit("not a .deb")
pos = 8
while pos + 60 <= len(data):
    name = data[pos:pos + 16].strip().decode()
    size = int(data[pos + 48:pos + 58])
    if name.startswith("control.tar"):
        body = data[pos + 60:pos + 60 + size]
        if len(body) < size:
            sys.exit("control.tar is past the bytes fetched")
        with tempfile.NamedTemporaryFile(suffix=name[len("control.tar"):]) as f:
            f.write(body)
            f.flush()
            control = subprocess.run(["tar", "-xOf", f.name, "./control"], check=True, capture_output=True).stdout.decode()
        for line in control.splitlines():
            if line.startswith("Version:"):
                print(line.split(":", 1)[1].strip().split("-")[0])
                sys.exit()
        sys.exit("no Version in control")
    pos += 60 + size + (size & 1)
sys.exit("no control.tar in the bytes fetched")
')"
[ -n "$version" ] || { echo "failed to read the package's version" >&2; exit 1; }
url="$probe"
echo "resolved Certisign WebSigner $version: $url" >&2
jq -n --arg v "$version" --arg u "$url" '{version:$v, sources:[{filename:"cswebsigner.deb", url:$u}]}'
