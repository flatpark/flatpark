#!/bin/sh
set -eu
# ToDesktop publishes the stable Linux release and immutable build filenames.
# GitHub releases carry notes but no binary assets.
curl -fsSL --retry 3 https://download.todesktop.com/241130tqe9q3y/latest-linux.yml | python3 -c '
import json, re, sys
text = sys.stdin.read()
def field(name):
    match = re.search(r"^" + name + r":\s*(.+)$", text, re.M)
    if not match:
        raise SystemExit("missing vendor metadata: " + name)
    return match.group(1).strip().strip(chr(39) + chr(34))
version, filename = field("version"), field("path")
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
    raise SystemExit("expected stable release")
if not re.fullmatch(r"comfyui-desktop-2-" + re.escape(version) + r"-build-[A-Za-z0-9]+-x86_64\.AppImage", filename):
    raise SystemExit("unexpected Linux x86_64 artifact")
print(json.dumps({"version": version, "releaseDate": field("releaseDate")[:10], "sources": [{"filename": "app.AppImage", "url": "https://download.todesktop.com/241130tqe9q3y/" + filename}]}))
'
