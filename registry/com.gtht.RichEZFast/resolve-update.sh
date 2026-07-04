#!/usr/bin/env bash
# Update resolver for Guotai Haitong RichEZFast.
#
# The public download page is rendered client-side. Its software list comes from
# /ows/software/queryPage, protected by the same lightweight ECDH + SM3 request
# headers used by the frontend SDK. This resolver recreates that flow without
# executing upstream JavaScript.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need openssl
need python3

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

openssl ecparam -name prime256v1 -genkey -noout -out "$tmp/private.pem"
openssl ec -in "$tmp/private.pem" -pubout -outform DER -out "$tmp/public.der" >/dev/null 2>&1

python3 - "$tmp/public.der" > "$tmp/security.json" <<'PY'
import base64
import json
import ssl
import sys
import urllib.request

APP_NAME = "OWS"
APP_ID = "GTJA-qxb#7GLNkUrB!mOSYX6&Mi6LTL@ndxe^"
BASE = "https://www.gtht.com"

def ssl_context():
    ctx = ssl.create_default_context()
    if hasattr(ssl, "OP_LEGACY_SERVER_CONNECT"):
        ctx.options |= ssl.OP_LEGACY_SERVER_CONNECT
    return ctx

public_key = base64.b64encode(open(sys.argv[1], "rb").read()).decode()
body = json.dumps({
    "frontPublicKey": public_key,
    "appName": APP_NAME,
    "appId": APP_ID,
}, separators=(",", ":")).encode()
req = urllib.request.Request(
    BASE + "/ows/sfst/security/1000001",
    data=body,
    headers={
        "Content-Type": "application/json",
        "Accept": "application/json,text/plain,*/*",
        "Origin": BASE,
        "Referer": BASE + "/download",
        "User-Agent": "Mozilla/5.0",
    },
    method="POST",
)
with urllib.request.urlopen(req, context=ssl_context(), timeout=30) as resp:
    print(resp.read().decode())
PY

python3 - "$tmp/security.json" "$tmp/backpub.der" <<'PY'
import base64
import json
import sys

data = json.load(open(sys.argv[1])).get("data") or {}
back_public_key = data.get("backPublicKey")
if not back_public_key:
    raise SystemExit("failed to resolve RichEZFast security public key")
open(sys.argv[2], "wb").write(base64.b64decode(back_public_key))
PY

openssl pkey -pubin -inform DER -in "$tmp/backpub.der" -out "$tmp/backpub.pem" >/dev/null 2>&1
openssl pkeyutl -derive -inkey "$tmp/private.pem" -peerkey "$tmp/backpub.pem" -out "$tmp/shared.bin"

python3 - "$tmp/security.json" "$tmp/shared.bin" <<'PY'
import base64
import json
import re
import ssl
import sys
import time
import urllib.request
import uuid

APP_NAME = "OWS"
APP_ID = "GTJA-qxb#7GLNkUrB!mOSYX6&Mi6LTL@ndxe^"
BASE = "https://www.gtht.com"

def ssl_context():
    ctx = ssl.create_default_context()
    if hasattr(ssl, "OP_LEGACY_SERVER_CONNECT"):
        ctx.options |= ssl.OP_LEGACY_SERVER_CONNECT
    return ctx

def rol(x, n):
    n %= 32
    return ((x << n) & 0xffffffff) | (x >> (32 - n))

def p0(x):
    return x ^ rol(x, 9) ^ rol(x, 17)

def p1(x):
    return x ^ rol(x, 15) ^ rol(x, 23)

def sm3_hex(data):
    if isinstance(data, str):
        data = data.encode()
    iv = [0x7380166f, 0x4914b2b9, 0x172442d7, 0xda8a0600,
          0xa96f30bc, 0x163138aa, 0xe38dee4d, 0xb0fb0e4e]
    msg = bytearray(data)
    bit_len = len(msg) * 8
    msg.append(0x80)
    while len(msg) % 64 != 56:
        msg.append(0)
    msg += bit_len.to_bytes(8, "big")

    v = iv[:]
    for off in range(0, len(msg), 64):
        block = msg[off:off + 64]
        w = [int.from_bytes(block[i:i + 4], "big") for i in range(0, 64, 4)]
        for j in range(16, 68):
            w.append(p1(w[j - 16] ^ w[j - 9] ^ rol(w[j - 3], 15)) ^ rol(w[j - 13], 7) ^ w[j - 6])
        w1 = [w[j] ^ w[j + 4] for j in range(64)]
        a, b, c, d, e, f, g, h = v
        for j in range(64):
            tj = 0x79cc4519 if j <= 15 else 0x7a879d8a
            ss1 = rol((rol(a, 12) + e + rol(tj, j)) & 0xffffffff, 7)
            ss2 = ss1 ^ rol(a, 12)
            ff = (a ^ b ^ c) if j <= 15 else ((a & b) | (a & c) | (b & c))
            gg = (e ^ f ^ g) if j <= 15 else ((e & f) | ((~e) & g))
            tt1 = (ff + d + ss2 + w1[j]) & 0xffffffff
            tt2 = (gg + h + ss1 + w[j]) & 0xffffffff
            d = c
            c = rol(b, 9)
            b = a
            a = tt1
            h = g
            g = rol(f, 19)
            f = e
            e = p0(tt2)
        v = [x ^ y for x, y in zip(v, [a, b, c, d, e, f, g, h])]
    return "".join(f"{x:08x}" for x in v)

security = json.load(open(sys.argv[1])).get("data") or {}
share_key = base64.b64encode(open(sys.argv[2], "rb").read()).decode()
server_time = int(security.get("backTimestamp") or int(time.time() * 1000))
request_rand = str(uuid.uuid4())
request_time = str(server_time)
request_hash = sm3_hex(request_rand + request_time)
request_sign = sm3_hex(APP_NAME + APP_ID + request_hash + share_key)

headers = {
    "Content-Type": "application/json",
    "Accept": "application/json,text/plain,*/*",
    "Origin": BASE,
    "Referer": BASE + "/download",
    "User-Agent": "Mozilla/5.0",
    "x-request-sign": request_sign,
    "x-request-rand": request_rand,
    "x-request-time": request_time,
    "x-app-id": APP_ID,
    "x-app-name": APP_NAME,
    "x-ecc-key": security.get("eccKey", ""),
    "x-sdk-version": "0.3.5",
}
body = json.dumps({"pageNum": 1, "pageSize": 100, "name": ""}, separators=(",", ":")).encode()
req = urllib.request.Request(BASE + "/ows/software/queryPage", data=body, headers=headers, method="POST")
with urllib.request.urlopen(req, context=ssl_context(), timeout=30) as resp:
    payload = json.loads(resp.read().decode())

rows = payload.get("rows") or payload.get("data") or []
matches = []

def is_kylin_x86_richeasy(row):
    url = str(row.get("pcDownloadUrl") or row.get("macDownloadUrl") or "")
    filename = url.rsplit("/", 1)[-1].lower()
    text = " ".join(str(row.get(k) or "") for k in (
        "name", "version", "title", "description", "operatingSystem", "pcCompatibleVersion"
    ))
    text_lower = text.lower()
    url_lower = url.lower()
    # Upstream publishes two x86 .debs with the same version:
    #   richeasy_<version>_amd64.deb            => Kylin
    #   com.gtht.richeasy_<version>_amd64.deb  => UnionTech/UOS
    # The filename is the stable discriminator; page copy is only a guard.
    if not re.fullmatch(r"richeasy_\d+(?:\.\d+)+_amd64\.deb", filename):
        return False
    if "富易" not in text and "richeasy" not in url_lower:
        return False
    if any(marker in text_lower for marker in ("统信", "uos", "aarch64", "arm64", "arm架构")):
        return False
    return True

for row in rows:
    if is_kylin_x86_richeasy(row):
        matches.append(row)

if not matches:
    raise SystemExit("failed to find RichEZFast Kylin Linux x86_64 package in software list")

row = sorted(matches, key=lambda r: (r.get("updateTime") or "", r.get("publishDate") or ""), reverse=True)[0]
version_text = str(row.get("version") or "")
listed_url = row.get("pcDownloadUrl") or row.get("macDownloadUrl") or ""
m = re.search(r"(\d+(?:\.\d+)+)", version_text) or re.search(r"richeasy[_-](\d+(?:\.\d+)+)", listed_url)
if not m:
    raise SystemExit(f"failed to parse RichEZFast version from {version_text!r} / {listed_url!r}")
version = m.group(1)
url = f"https://dl2.app.gtja.com/public/fy-pro/linux/richeasy_{version}_amd64.deb"
if listed_url and listed_url != url:
    raise SystemExit(f"RichEZFast Kylin URL pattern changed: listed {listed_url!r}, expected {url!r}")
release_date = ""
if row.get("updateTime"):
    release_date = str(row["updateTime"])[:10]
elif row.get("publishDate"):
    release_date = str(row["publishDate"])[:10]

print(json.dumps({
    "version": version,
    "releaseDate": release_date,
    "sources": [{"filename": "richeasy.deb", "url": url}],
}, ensure_ascii=False, indent=2))
PY
