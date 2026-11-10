#!/usr/bin/env python3
"""Read-only production release selection; FlatPark manages hashing and pins."""
from collections import Counter
from datetime import datetime,timezone
import json
import os
import re
import sys
import urllib.request

REPOSITORY='jing2uo/vlc-nightly-release'
# The repository was transferred from rhgKc2yp. GitHub now serves every release
# (and its download URLs) under the new owner, but release.json is a signed,
# immutable asset: releases published before the transfer still record the old
# name in `repository` and in each asset `url`. Accept that name only inside
# release.json; the API side and emitted pins always use REPOSITORY.
LEGACY_REPOSITORIES=('rhgKc2yp/vlc-nightly-release',)
VERSION=re.compile(r'4\.0\.0-dev-\d+-g[0-9a-f]+-r\d+-qt[0-9a-f]{16}')


def fetch(url):
    headers={'Accept':'application/vnd.github+json','User-Agent':'FlatPark-VLCBeta'}
    # Never send API credentials to download/redirect hosts.
    token=os.getenv('GITHUB_TOKEN') or os.getenv('GH_TOKEN')
    if token and url.startswith('https://api.github.com/'):
        headers['Authorization']='Bearer '+token
    with urllib.request.urlopen(urllib.request.Request(url,headers=headers),timeout=30) as response:
        return json.load(response)


def select(releases,load,now=None):
    now=now or datetime.now(timezone.utc)
    if not isinstance(releases,list):raise ValueError('GitHub releases response is not an array')
    for release in sorted(releases,key=lambda r:r.get('published_at') or '',reverse=True):
        if release.get('draft') is not False or type(release.get('prerelease')) is not bool or not VERSION.fullmatch(release.get('tag_name','')):continue
        version=release['tag_name'];base=f'https://github.com/{REPOSITORY}/releases/download/{version}/'
        assets=release.get('assets',[]);counts=Counter(a.get('name') for a in assets)
        names={f'vlc-{version}-{arch}.tar.zst' for arch in ('x86_64','aarch64')}
        if any(counts[n]!=1 for n in names|{'release.json','provenance.intoto.jsonl'}):continue
        if {a.get('name') for a in assets if a.get('name','').endswith('.tar.zst')}!=names:continue
        indexed={a['name']:a for a in assets}
        if any(indexed[n].get('state')!='uploaded' or not indexed[n].get('size',0)>0 for n in ['release.json','provenance.intoto.jsonl']):continue
        if indexed['release.json'].get('browser_download_url')!=base+'release.json':continue
        # Fetch failures (including rate limits) fail closed, never emit partial JSON.
        data=load(base+'release.json')
        if not isinstance(data,dict):continue
        recorded=data.get('repository')
        if (data.get('schema')!=1 or data.get('channel')!='production' or recorded not in (REPOSITORY,*LEGACY_REPOSITORIES)
                or data.get('version')!=version or data.get('runtime')!='org.kde.Platform//6.11'
                or data.get('attestation_required') is not True
                or not re.fullmatch('[0-9a-f]{40}',data.get('upstream_sha',''))):continue
        identity=data.get('qt_abi_identity','')
        if not re.fullmatch('[0-9a-f]{64}',identity) or not version.endswith('-qt'+identity[:16]):continue
        outcome=data.get('automated_status');issues=data.get('known_issues')
        if outcome=='PASS':
            if issues!=[]:continue
        elif outcome=='WAIVED':
            if not isinstance(issues,list) or len(issues)!=1:continue
            issue=issues[0]
            if (issue.get('id')!='VLC-X11-RAPID-QUIT-AARCH64-2026-11'
                    or issue.get('architecture')!='aarch64' or issue.get('test')!='xcb-gui-openuri-quit-rapid'
                    or issue.get('source_commit')!=data['upstream_sha'] or issue.get('decision')!='WAIVED'
                    or issue.get('exit_code')!=134 or issue.get('expires_at')!='2026-11-16T00:00:00Z'
                    or not datetime(2026,11,2,tzinfo=timezone.utc)<=now<datetime(2026,11,16,tzinfo=timezone.utc)):continue
        else:continue
        if set(data.get('assets',{}))!={'x86_64','aarch64'}:continue
        sources=[]
        for arch in ('x86_64','aarch64'):
            name=f'vlc-{version}-{arch}.tar.zst';asset=indexed[name];record=data['assets'][arch]
            recorded_base=f'https://github.com/{recorded}/releases/download/{version}/'
            if (record.get('name')!=name or record.get('url')!=recorded_base+name
                    or asset.get('browser_download_url')!=base+name or asset.get('state')!='uploaded'
                    or type(record.get('size')) is not int or not 0<record['size']<2**31
                    or asset.get('size')!=record['size']
                    or not re.fullmatch('[0-9a-f]{64}',record.get('sha256',''))
                    or asset.get('digest')!='sha256:'+record['sha256']
                    or record.get('verification')!=('WAIVED' if arch=='aarch64' and outcome=='WAIVED' else 'PASS')):break
            sources.append(dict(filename='vlc.tar.zst',arch=arch,url=base+name,size=record['size']))
        if len(sources)!=2:continue
        published=release.get('published_at','')
        if not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z',published):continue
        return dict(version=version,releaseDate=published[:10],releaseUrl=release['html_url'],sources=sources)
    raise ValueError('No eligible complete production release; keep the existing package pin')


def main():
    releases=[]
    for page in range(1,4):
        batch=fetch(f'https://api.github.com/repos/{REPOSITORY}/releases?per_page=100&page={page}')
        if not isinstance(batch,list):raise ValueError('Malformed releases response')
        releases.extend(batch)
        if len(batch)<100:break
    print(json.dumps(select(releases,fetch)))


if __name__=='__main__':
    try:main()
    except Exception as error:
        print('VLCBeta resolver: '+str(error),file=sys.stderr);raise SystemExit(1)
