#!/usr/bin/env bash
# Update resolver for Root.
#
# Root publishes Linux builds through a Velopack feed, one per arch. The
# download page links an unversioned Root.AppImage; the feed lists each release
# as a versioned full package (a zip whose only payload is that same AppImage,
# at lib/app/Root.AppImage) with its SHA-256 and size, so the pin is taken
# without a download. Delta packages are skipped. The feed gives no release
# date, so the release is dated the day it is picked up.
# Prints JSON on stdout:
#   { "version": "0.9.164",
#     "sources": [ { "filename": "root.nupkg", "arch": "x86_64", "url": "...", "sha256": "...", "size": N }, ... ] }
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

base="https://installer.rootapp.com/installer/Linux"

latest() { # feed directory: X64 | Arm64
  curl -fsSL "$base/$1/releases.linux.json" | jq -c '
    [ .Assets[] | select(.Type == "Full" and .PackageId == "Root")
                | select(.Version | test("^[0-9]+(\\.[0-9]+)+$")) ]
    | max_by(.Version | split(".") | map(tonumber))'
}
x64="$(latest X64)"
arm="$(latest Arm64)"

v_x64="$(jq -r '.Version // empty' <<<"$x64")"
v_arm="$(jq -r '.Version // empty' <<<"$arm")"
[ -n "$v_x64" ] || { echo "no full package in the x64 feed" >&2; exit 1; }
# One version for both arches; if the feeds disagree mid-rollout, wait.
[ "$v_x64" = "$v_arm" ] || { echo "x64 feed has $v_x64, arm64 feed has ${v_arm:-nothing}" >&2; exit 1; }

src() { # feed directory, asset JSON, flatpak arch
  jq -c --arg b "$base/$1" --arg a "$3" '{
      filename: "root.nupkg", arch: $a,
      url: ($b + "/" + .FileName),
      sha256: (.SHA256 | ascii_downcase), size: .Size }' <<<"$2"
}
sx64="$(src X64 "$x64" x86_64)"
sarm="$(src Arm64 "$arm" aarch64)"
for s in "$sx64" "$sarm"; do
  jq -e '.url | test("/Root-[0-9.]+-linux-full\\.nupkg$")' <<<"$s" >/dev/null \
    || { echo "unexpected package name: $s" >&2; exit 1; }
done

echo "resolved Root $v_x64" >&2
jq -n --arg v "$v_x64" --argjson a "$sx64" --argjson b "$sarm" \
  '{version:$v, sources:[$a, $b]}'
