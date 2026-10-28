#!/usr/bin/env bash
set -euo pipefail
# Resolve only stable releases and require exactly one official tarball per arch.
rel="$(curl -fsSL --retry 3 --max-time 60 ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    https://api.github.com/repos/google-deepmind/mujoco/releases/latest)"
printf '%s' "$rel" | python3 -c '
import json, re, sys
r = json.load(sys.stdin)
v = r["tag_name"]
if r.get("draft") or r.get("prerelease") or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", v):
    sys.exit("expected a stable MuJoCo release")
sources = []
for arch in ("x86_64", "aarch64"):
    name = "mujoco-" + v + "-linux-" + arch + ".tar.gz"
    assets = [a for a in r["assets"] if a["name"] == name]
    if len(assets) != 1:
        sys.exit("expected exactly one official " + arch + " tarball")
    a = assets[0]
    sources.append({"filename": "mujoco.tar.gz", "arch": arch,
                    "url": a["browser_download_url"], "size": a["size"]})
print(json.dumps({"version": v, "releaseDate": r["published_at"][:10],
                  "releaseUrl": r["html_url"], "sources": sources}))
'
