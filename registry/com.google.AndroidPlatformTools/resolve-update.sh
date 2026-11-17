#!/usr/bin/env bash
set -euo pipefail
# Google's stable SDK channel supplies versioned URLs; ignore previews.
exec python3 - <<'PYTHON'
import json
import urllib.request
import xml.etree.ElementTree as ET
base = "https://dl.google.com/android/repository/"
with urllib.request.urlopen(base + "repository2-3.xml", timeout=60) as response:
    root = ET.parse(response).getroot()
releases = []
for package in root.findall("remotePackage"):
    if package.get("path") != "platform-tools":
        continue
    channel = package.find("channelRef")
    if channel is None or channel.get("ref") != "channel-0":
        continue
    revision = package.find("revision")
    if revision.find("preview") is not None:
        continue
    version = tuple(int(revision.findtext(part, "0")) for part in ("major", "minor", "micro"))
    for archive in package.findall("archives/archive"):
        if archive.findtext("host-os") != "linux":
            continue
        complete = archive.find("complete")
        name = complete.findtext("url", "")
        expected = "platform-tools_r" + ".".join(map(str, version)) + "-linux.zip"
        if name != expected:
            raise SystemExit("unexpected Linux platform-tools URL: " + name)
        releases.append((version, {"filename": "platform-tools.zip", "arch": "x86_64",
                                  "url": base + name, "size": int(complete.findtext("size"))}))
if not releases:
    raise SystemExit("stable Linux platform-tools release not found")
version, source = max(releases, key=lambda release: release[0])
print(json.dumps({"version": ".".join(map(str, version)), "sources": [source]}))
PYTHON
