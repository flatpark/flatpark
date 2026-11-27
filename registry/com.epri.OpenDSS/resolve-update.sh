#!/usr/bin/env bash
set -euo pipefail
# The official feed contains installer filenames and dates. Read the version
# from the accompanying upstream README, rather than guessing from filenames.
feed="$(curl -fsSL --retry 3 'https://sourceforge.net/projects/electricdss/rss?path=/OpenDSS')"
readme="$(curl -fsSL --retry 3 'https://downloads.sourceforge.net/project/electricdss/OpenDSS/README.txt')"
python3 - "$feed" "$readme" <<'PY'
import email.utils, json, re, sys, xml.etree.ElementTree as ET
feed, readme = sys.argv[1:]
versions = re.findall(r'^Version\s+(\d+(?:\.\d+){3})\b', readme, re.M | re.I)
if len(versions) != 1:
    raise SystemExit('expected one version in upstream README')
version = versions[0]
items = []
for item in ET.fromstring(feed).findall('./channel/item'):
    path = item.findtext('title', '')
    if re.fullmatch(r'/OpenDSS/OpenDSSInstaller_?\d+_\d+\.exe', path):
        items.append((email.utils.parsedate_to_datetime(item.findtext('pubDate')), path, item))
if not items:
    raise SystemExit('no OpenDSS installer in feed')
date, path, item = max(items, key=lambda x: x[0])
# Upstream filenames encode the major, minor, patch and revision digits.
parts = version.split('.')
expected = ''.join(parts[:3]) + '_' + parts[3]
if not re.fullmatch(r'/OpenDSS/OpenDSSInstaller_?' + re.escape(expected) + r'\.exe', path):
    raise SystemExit('newest installer does not match README version')
content = item.find('{http://video.search.yahoo.com/mrss/}content')
if content is None or not content.get('filesize'):
    raise SystemExit('installer has no feed size')
print(json.dumps({'version': version, 'releaseDate': date.date().isoformat(), 'sources': [{'filename': 'OpenDSSInstaller.exe', 'url': 'https://downloads.sourceforge.net/project/electricdss' + path, 'size': int(content.get('filesize'))}]}))
PY
