#!/usr/bin/env bash
set -euo pipefail
# Official SourceForge RSS lists complete release paths and publication dates.
# Select the newest stable x86_64 Linux Debian release.
feed="$(curl -fsSL --retry 3 'https://sourceforge.net/projects/projectlibre/rss?path=/ProjectLibre')"
python3 - "$feed" <<'PY'
import email.utils
import json
import re
import sys
import xml.etree.ElementTree as ET

releases = {}
for item in ET.fromstring(sys.argv[1]).findall('./channel/item'):
    path = item.findtext('title', '')
    match = re.fullmatch(r'/ProjectLibre/(\d+(?:\.\d+)+)/projectlibre_\1_(amd64)\.deb', path)
    if not match:
        continue
    version, arch = match.groups()
    releases.setdefault(version, {})[arch] = (path, item.findtext('pubDate'))
complete = [v for v, assets in releases.items() if 'amd64' in assets]
if not complete:
    raise SystemExit('No stable ProjectLibre x86_64 Debian release')
version = max(complete, key=lambda v: tuple(map(int, v.split('.'))))
assets = releases[version]
print(json.dumps({
    'version': version,
    'releaseDate': email.utils.parsedate_to_datetime(assets['amd64'][1]).date().isoformat(),
    'releaseUrl': f'https://sourceforge.net/projects/projectlibre/files/ProjectLibre/{version}/',
    'sources': [{'filename': 'projectlibre.deb', 'arch': 'x86_64',
                 'url': 'https://downloads.sourceforge.net/project/projectlibre' + assets['amd64'][0]}]
}, indent=2))
PY
