#!/bin/sh
set -eu
# Resolve the complete, matching VLC split-package set from Ubuntu 26.10 only.
exec python3 - <<'PY'
import datetime, gzip, json, re, urllib.request
base = 'https://ppa.launchpadcontent.net/videolan/master-daily/ubuntu/'
index = gzip.decompress(urllib.request.urlopen(base + 'dists/stonking/main/binary-amd64/Packages.gz', timeout=60).read()).decode()
packages = {}
for paragraph in index.strip().split('\n\n'):
    record = {}
    for line in paragraph.splitlines():
        if line and not line.startswith(' '):
            key, _, value = line.partition(': ')
            record[key] = value
    if 'Package' in record:
        packages[record['Package']] = record
names = ['vlc', 'vlc-bin', 'vlc-data', 'libvlc-bin', 'libvlc5', 'libvlccore9',
         'vlc-plugin-base', 'vlc-plugin-qt', 'vlc-plugin-video-output']
version = packages['vlc']['Version']
if not version.startswith('4.0.') or 'ubuntu26.10' not in version:
    raise SystemExit('Expected a VLC 4 Ubuntu 26.10 development build')
if any(packages[name]['Version'] != version for name in names):
    raise SystemExit('PPA split packages have mismatched versions')
match = re.search(r'git(\d{8})', version)
if not match:
    raise SystemExit('Build date missing from PPA version')
date = datetime.datetime.strptime(match[1], '%Y%m%d').date().isoformat()
print(json.dumps({'version': version, 'releaseDate': date, 'sources': [
    {'filename': name + '.deb', 'url': base + packages[name]['Filename'], 'arch': 'x86_64'}
    for name in names]}))
PY
