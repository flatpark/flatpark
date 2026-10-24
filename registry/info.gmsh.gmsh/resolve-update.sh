#!/usr/bin/env bash
set -euo pipefail

# The official download page identifies the stable version, date and Linux
# artifact. Ignore development snapshots and the separate SDK tarball.
curl -fsSL --retry 3 --max-time 60 https://gmsh.info/ | python3 -c '
import datetime
import json
import re
import sys

page = sys.stdin.read()
releases = re.findall(
    r"Current stable release\s*\(version\s+(\d+\.\d+\.\d+),\s*(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})\)",
    page,
)
if len(releases) != 1:
    sys.exit("expected one stable Gmsh release on the official download page")
version, day, month, year = releases[0]
months = "January February March April May June July August September October November December".split()
date = datetime.date(int(year), months.index(month) + 1, int(day)).isoformat()
path = "bin/Linux/gmsh-" + version + "-Linux64.tgz"
if not re.search(r"href=\"" + re.escape(path) + r"\"", page):
    sys.exit("stable Linux x86_64 tarball missing from official download page")
print(json.dumps({
    "version": version,
    "releaseDate": date,
    "sources": [{"filename": "gmsh.tgz", "arch": "x86_64", "url": "https://gmsh.info/" + path}],
}))
'
