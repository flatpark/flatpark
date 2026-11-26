#!/usr/bin/env bash
# check-stale.mjs: which "newer upstream release" counts against a resolver.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v node >/dev/null 2>&1 || { echo "test_check_stale: SKIP (no node)"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
reg="$tmp/registry"
for id in io.t.Renamed io.t.Current io.t.Mono io.t.Backport io.t.Vendor io.t.Fresh; do
    mkdir -p "$reg/$id"; printf 'id: %s\nupdate:\n  command: ./resolve-update.sh\n' "$id" > "$reg/$id/flatpark.yml"
done
printf "  stale_ignore: '^(?!app-)'\n" >> "$reg/io.t.Mono/flatpark.yml"

src() { printf '{"version":"x","sources":[{"filename":"a","url":"https://github.com/%s/releases/download/%s/a.tar.gz"}]}' "$1" "$2"; }
{
    printf 'io.t.Renamed\t%s\n'  "$(src o/renamed v1.2.0)"
    printf 'io.t.Current\t%s\n'  "$(src o/current v2.0.0)"
    printf 'io.t.Mono\t%s\n'     "$(src o/mono app-v3)"
    printf 'io.t.Backport\t%s\n' "$(src o/backport v1.7.1)"
    printf 'io.t.Vendor\t{"version":"1","sources":[{"filename":"a","url":"https://vendor.example/a.deb"}]}\n'
    printf 'io.t.Fresh\t%s\n'    "$(src o/fresh v1.0.0)"
} > "$tmp/resolved.tsv"

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$tmp/releases.json" <<JSON
{
  "o/renamed": { "picked": {"publishedAt":"2026-01-01T00:00:00Z","isPrerelease":false}, "releases": [
    {"tagName":"v1.3.0-rc1","name":"","isDraft":false,"isPrerelease":true,"publishedAt":"2026-03-01T00:00:00Z","assets":["app-1.3.0-linux-x86_64.tar.gz"]},
    {"tagName":"v1.2.1","name":"","isDraft":false,"isPrerelease":false,"publishedAt":"2026-02-01T00:00:00Z","assets":["app-1.2.1-linux-x86_64.tar.gz","app-1.2.1.exe"]},
    {"tagName":"v1.2.0","name":"","isDraft":false,"isPrerelease":false,"publishedAt":"2026-01-01T00:00:00Z","assets":["app-1.2.0-linux-x86_64.tar.xz"]} ] },
  "o/current": { "picked": {"publishedAt":"2026-01-01T00:00:00Z","isPrerelease":false}, "releases": [
    {"tagName":"v2.1.0","name":"","isDraft":false,"isPrerelease":false,"publishedAt":"2026-02-01T00:00:00Z","assets":["app-2.1.0-win-x64.exe","app-2.1.0-mac-arm64.dmg","latest-linux.yml"]},
    {"tagName":"v2.0.0","name":"","isDraft":false,"isPrerelease":false,"publishedAt":"2026-01-01T00:00:00Z","assets":["app-2.0.0_amd64.deb"]} ] },
  "o/mono": { "picked": {"publishedAt":"2026-01-01T00:00:00Z","isPrerelease":false}, "releases": [
    {"tagName":"lib-v9","name":"","isDraft":false,"isPrerelease":false,"publishedAt":"2026-02-01T00:00:00Z","assets":["lib-x86_64.tar.gz"]} ] },
  "o/backport": { "picked": {"publishedAt":"2026-01-01T00:00:00Z","isPrerelease":false}, "releases": [
    {"tagName":"v1.7.0","name":"","isDraft":false,"isPrerelease":false,"publishedAt":"2026-02-01T00:00:00Z","assets":["app-v1.7.0-x86_64.tar.gz"]} ] },
  "o/fresh": { "picked": {"publishedAt":"2026-01-01T00:00:00Z","isPrerelease":false}, "releases": [
    {"tagName":"v1.0.1","name":"","isDraft":false,"isPrerelease":false,"publishedAt":"$now","assets":["app-1.0.1-x86_64.AppImage"]} ] }
}
JSON

out="$(FLATPARK_REGISTRY_DIR="$reg" node "$ROOT/scripts/check-stale.mjs" "$tmp/resolved.tsv" --releases-file "$tmp/releases.json")"
want="$(printf 'io.t.Renamed\tv1.2.0\tv1.2.1')"
[ "$out" = "$want" ] || { printf 'FAIL: got\n%s\nwant\n%s\n' "$out" "$want"; exit 1; }
echo "test_check_stale: ok"
