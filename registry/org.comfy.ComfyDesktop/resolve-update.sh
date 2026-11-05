#!/bin/sh
set -eu
# ToDesktop publishes the stable Linux release and immutable build filenames.
# GitHub releases carry notes but no binary assets. latest-linux.yml lists the
# AppImage as `path:` and both builds under `files:`; take the amd64 .deb.
base=https://download.todesktop.com/241130tqe9q3y
curl -fsSL --retry 3 "$base/latest-linux.yml" | BASE="$base" python3 -c '
import json, os, re, sys
text = sys.stdin.read()
def field(name):
    match = re.search(r"^" + name + r":\s*(.+)$", text, re.M)
    if not match:
        raise SystemExit("missing vendor metadata: " + name)
    return match.group(1).strip().strip(chr(39) + chr(34))
version = field("version")
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
    raise SystemExit("expected stable release")
pattern = r"comfyui-desktop-2-" + re.escape(version) + r"-build-[A-Za-z0-9]+-amd64\.deb"
debs = sorted(set(re.findall(r"^\s*-?\s*url:\s*[\x27\x22]?(" + pattern + r")[\x27\x22]?\s*$", text, re.M)))
if len(debs) != 1:
    raise SystemExit("expected exactly one Linux amd64 .deb, found %d" % len(debs))
print(json.dumps({"version": version, "releaseDate": field("releaseDate")[:10], "sources": [{"filename": "app.deb", "url": os.environ["BASE"] + "/" + debs[0]}]}))
'
