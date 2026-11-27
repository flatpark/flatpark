#!/usr/bin/env bash
set -euo pipefail

# Loxone's root-level Release entry tracks stable Config. Nested entries are
# for other products, and the Beta and Test channels are skipped.
curl -fsSL --retry 3 https://update.loxone.com/updatecheck.xml | python3 -c '
import json
import re
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.stdin).getroot()
releases = root.findall("Release")
if root.tag != "Miniserversoftware" or len(releases) != 1:
    sys.exit("Expected one stable Config release in the Loxone update feed")

version = releases[0].get("Version", "")
url = releases[0].get("Path", "")
if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){3}", version) or not re.fullmatch(
    r"https?://updatefiles\.loxone\.com/LoxConfig/LoxoneConfigSetup_[0-9]+\.zip", url
):
    sys.exit("Invalid stable Config version or installer URL in the Loxone update feed")

print(json.dumps({
    "version": version,
    "sources": [{"filename": "loxone-config.zip", "url": url.replace("http:", "https:", 1)}],
}))
'
