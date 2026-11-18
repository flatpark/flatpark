#!/usr/bin/env bash
# Read the version, total size and Last-Modified date from the official rolling Debian download.
# The range is intentionally bounded; a changed archive layout fails closed.
set -euo pipefail

exec python3 - <<'PY'
import io
import json
import re
import subprocess
import sys
import tarfile
from email.utils import parsedate_to_datetime

URL = "https://www.eudic.net/download/eudic.deb"
LIMIT = 200001

def resolve():
    response = subprocess.run(
        ["curl", "-fsSL", "--max-time", "30", "--max-filesize", str(LIMIT),
         "-H", "Accept-Encoding: identity", "-r", f"0-{LIMIT - 1}",
         "-w", "\n%{http_code} %header{content-range}\t%header{last-modified}\n", URL],
        stdout=subprocess.PIPE, check=True,
    ).stdout
    if len(response) <= LIMIT or response[LIMIT:LIMIT + 1] != b"\n":
        raise ValueError("invalid response length")
    data = response[:LIMIT]
    metadata, _, modified = response[LIMIT + 1:].decode("ascii").strip().partition("\t")
    match = re.fullmatch(r"206 bytes 0-(\d+)/(\d+)", metadata)
    if not match:
        raise ValueError("server did not return the requested byte range")
    end, total = map(int, match.groups())
    if end != LIMIT - 1 or total <= end:
        raise ValueError("unexpected Content-Range")
    if len(data) != LIMIT or not data.startswith(b"!<arch>\n"):
        raise ValueError("invalid or incomplete Debian archive header")

    offset = 8
    control = None
    while offset + 60 <= len(data):
        header = data[offset:offset + 60]
        if header[58:60] != b"`\n":
            raise ValueError("invalid ar member header")
        name = header[:16].decode("ascii").strip().rstrip("/")
        size = int(header[48:58].decode("ascii").strip())
        start = offset + 60
        end = start + size
        if name == "control.tar.zst":
            if end > len(data):
                raise ValueError("control archive exceeds the requested range")
            control = data[start:end]
            break
        if end > len(data):
            raise ValueError("control archive not found in the requested range")
        offset = end + (size % 2)
    if control is None:
        raise ValueError("control.tar.zst not found in the requested range")

    result = subprocess.run(["zstd", "-d", "-c", "-q"], input=control, stdout=subprocess.PIPE, check=True)
    with tarfile.open(fileobj=io.BytesIO(result.stdout), mode="r:") as archive:
        files = [m for m in archive.getmembers() if m.name in ("control", "./control") and m.isfile()]
        if len(files) != 1 or files[0].size > 65536:
            raise ValueError("missing or ambiguous Debian control file")
        control_text = archive.extractfile(files[0]).read().decode("utf-8")
    fields = {}
    for line in control_text.splitlines():
        if ":" in line and not line.startswith((" ", "\t")):
            key, value = line.split(":", 1)
            if key in fields:
                raise ValueError(f"duplicate control field: {key}")
            fields[key] = value.strip()
    version = fields.get("Version", "")
    if fields.get("Package") != "eudic" or fields.get("Architecture") != "amd64":
        raise ValueError("unexpected Debian package or architecture")
    if not re.fullmatch(r"[0-9][A-Za-z0-9.+:~\-]*", version):
        raise ValueError("invalid or missing Debian version")
    result = {"version": version, "sources": [{"filename": "eudic.deb", "url": URL, "size": total}]}
    # Upstream publishes no release date; the rolling file's Last-Modified is the closest.
    try:
        result["releaseDate"] = parsedate_to_datetime(modified).date().isoformat()
    except (TypeError, ValueError):
        pass
    return result

try:
    print(json.dumps(resolve(), ensure_ascii=True))
except (OSError, ValueError, subprocess.CalledProcessError, tarfile.TarError) as exc:
    print(f"Eudic update resolution failed: {exc}", file=sys.stderr)
    sys.exit(1)
PY
