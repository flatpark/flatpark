#!/usr/bin/env bash
# Update resolver for Ycode.
#
# Prints the newest release and its two Linux tarballs as JSON on stdout; logs
# go to stderr. Only plain release-asset URLs are emitted: update-pins.mjs reads
# each asset's sha256 (`digest`) and size from the releases API, so nothing is
# downloaded to pin it.
#
# Which release: one that carries both Ycode-<version>-{x86_64,aarch64}.tar.xz
# (a release still uploading, or one with only the macOS .dmg, is skipped rather
# than failing the sweep). Ycode has only shipped betas (1.0.0-beta.N); they are
# currently published as full releases, but the package follows betas, and one
# flagged as a GitHub pre-release would be invisible to /releases/latest. So
# the list is read instead: the newest (by published_at) full release if there
# is one, otherwise the newest pre-release. A later pre-release then never
# replaces a full release on the stable branch.
set -euo pipefail

repo="MarcoDotIO/Ycode"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=50")"

sel="$(jq -c '
  [ .[]
    | select(.draft == false)
    | (.tag_name | ltrimstr("v")) as $v
    | { version: $v,
        pre: .prerelease,
        published: (.published_at // ""),
        date: (.published_at // "" | .[0:10]),
        page: .html_url,
        x86: ([ .assets[] | select(.name == "Ycode-\($v)-x86_64.tar.xz")  | .browser_download_url ] | first),
        arm: ([ .assets[] | select(.name == "Ycode-\($v)-aarch64.tar.xz") | .browser_download_url ] | first) }
    | select(.x86 != null and .arm != null and .date != "")
  ]
  | sort_by(.published)
  | (map(select(.pre | not)) | last) // last // empty' <<<"$rels")"

[ -n "$sel" ] || { echo "no Ycode release with both Linux tarballs" >&2; exit 1; }

version="$(jq -r .version <<<"$sel")"
echo "resolved Ycode $version ($(jq -r .date <<<"$sel"), prerelease: $(jq -r .pre <<<"$sel"))" >&2

jq '{version, releaseDate: .date, releaseUrl: .page,
     sources: [ {filename: "ycode.tar.xz", arch: "x86_64",  url: .x86},
                {filename: "ycode.tar.xz", arch: "aarch64", url: .arm} ]}' <<<"$sel"
