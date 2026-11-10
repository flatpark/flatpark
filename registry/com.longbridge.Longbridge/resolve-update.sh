#!/usr/bin/env bash
# Update resolver for Longbridge.
#
# Prints the current version + Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.17.2", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "longbridge.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting -- FlatPark downloads the
# URL and computes the extra-data sha256/size at update time.
set -euo pipefail

LATEST_URL="https://assets.lbkrs.com/github/release/longbridge-desktop/stable/latest.json"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need python3

latest="$(curl -fsSL --compressed "$LATEST_URL")"

python3 - "$latest" <<'PY'
import json
import sys

latest = json.loads(sys.argv[1])
version = latest.get("version")
published_at = latest.get("published_at") or latest.get("created_at") or ""
release_date = published_at[:10] if published_at else ""

url = ""
for asset in latest.get("assets", []):
    name = asset.get("name", "")
    if name.endswith("linux-x86_64.deb"):
        url = asset.get("url", "")
        break

if not version or not url:
    raise SystemExit("failed to resolve Longbridge release")

print(json.dumps({
    "version": version,
    "releaseDate": release_date,
    "sources": [{"filename": "longbridge.deb", "url": url}],
}, indent=2))
PY
