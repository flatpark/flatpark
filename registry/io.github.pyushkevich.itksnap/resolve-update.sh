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
import sys,re,json,xml.etree.ElementTree as E,email.utils
v=sys.argv[1]; r=E.fromstring(sys.stdin.read()); candidates=[]
for i in r.findall("./channel/item"):
 name=i.findtext("title","").rsplit("/",1)[-1]
 m=re.fullmatch(r"itksnap-"+re.escape(v)+r"-(\d{8})-Linux-x86_64\.tar\.gz",name)
 if m: candidates.append((m[1],name,i.findtext("pubDate")))
if not candidates: raise SystemExit("no stable Linux x86_64 tarball")
build,name,date=max(candidates)
print(json.dumps({"version":v+"-"+build,"releaseDate":email.utils.parsedate_to_datetime(date).date().isoformat(),"sources":[{"filename":"itksnap.tar.gz","url":"https://downloads.sourceforge.net/project/itk-snap/itk-snap/"+v+"/"+name}]}))
' "$version"
