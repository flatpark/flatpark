#!/usr/bin/env bash
set -euo pipefail
# The global RSS feed is dominated by nightlies. Select the newest numeric
# stable directory first, then read only that release's official file feed.
listing="$(curl -fsSL --retry 3 https://sourceforge.net/projects/itk-snap/files/itk-snap/)"
version="$(printf '%s' "$listing" | python3 -c '
import re,sys
v=set(re.findall(r"/projects/itk-snap/files/itk-snap/(\d+\.\d+\.\d+)/",sys.stdin.read()))
if not v: raise SystemExit("no stable ITK-SNAP release directory")
print(max(v,key=lambda x:tuple(map(int,x.split(".")))))
')"
curl -fsSL --retry 3 "https://sourceforge.net/projects/itk-snap/rss?path=/itk-snap/$version" |
python3 -c '
import sys,json,xml.etree.ElementTree as E,email.utils
v=sys.argv[1]; r=E.fromstring(sys.stdin.read())
# Since 4.6.0 the portable build is itksnap-<version>-linux-x64.tar.gz (no
# build date). x86_64 only: the libssh/krb5-gss support pins are x86_64.
name="itksnap-"+v+"-linux-x64.tar.gz"
items=[i for i in r.findall("./channel/item") if i.findtext("title","").rsplit("/",1)[-1]==name]
if len(items)!=1: raise SystemExit("expected exactly one stable Linux x64 tarball")
# Upstream re-uploads under the same name (4.6.0 was re-cut on 2026-11-23), so
# pass the feed filesize: update-pins re-pins when it drifts from the pin.
mc=items[0].find("{http://video.search.yahoo.com/mrss/}content")
size=mc.get("filesize") if mc is not None else None
if not size: raise SystemExit("no filesize for "+name+" in the release feed")
print(json.dumps({"version":v,"releaseDate":email.utils.parsedate_to_datetime(items[0].findtext("pubDate")).date().isoformat(),"sources":[{"filename":"itksnap.tar.gz","url":"https://downloads.sourceforge.net/project/itk-snap/itk-snap/"+v+"/"+name,"size":int(size)}]}))
' "$version"
