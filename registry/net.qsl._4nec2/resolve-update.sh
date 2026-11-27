#!/usr/bin/env bash
set -euo pipefail
url=https://qsl.net/4nec2/4nec2.zip
page="$(curl -fsSL --retry 3 https://qsl.net/4nec2/Home.htm)"
version="$(printf '%s' "$page" | tr '\n' ' ' | sed -nE 's/.*Latest 4nec2 version<\/a>[[:space:]]*\(([0-9]+(\.[0-9]+)+)\).*/\1/p')"
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo 'Could not find upstream version' >&2; exit 1; }
headers="$(curl -fsSI --retry 3 "$url")"
modified="$(sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' <<<"$headers" | tr -d '\r' | tail -n1)"
[ -n "$modified" ] || { echo 'Missing Last-Modified header' >&2; exit 1; }
stamp="$(date -u -d "$modified" +%Y%m%d%H%M%S)"
release_date="$(date -u -d "$modified" +%Y-%m-%d)"
jq -n --arg v "$version-$stamp" --arg d "$release_date" --arg u "$url" '{version:$v, releaseDate:$d, sources:[{filename:"4nec2.zip", url:$u}]}'
