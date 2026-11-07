#!/usr/bin/env bash
# An extension in the registry: the audit's gates, the stand-in's metadata,
# discovery, a parent's runtime move, the delist and the app page.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v git >/dev/null || { echo "test_extensions: SKIP (no git)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cp -r "$ROOT/scripts" "$ROOT/config" "$tmp/"
reg="$tmp/registry"; P=io.flatpark.Hub; E=$P.Driver.Foo
mkdir -p "$reg/$P" "$reg/$E"

cat > "$reg/$P/flatpark.yml" <<EOF
id: $P
name: Hub
summary: Synthetic parent
build:
  manifest: $P.yml
EOF
cat > "$reg/$P/$P.yml" <<EOF
id: $P
runtime: org.gnome.Platform
runtime-version: "51"
sdk: org.gnome.Sdk
command: hub
finish-args:
  - --share=network
add-extensions:
  # A comment between the points.
  $P.Driver:
    directory: lib/hub/extensions
    subdirectories: true
    no-autodownload: true
  $P.Single:
    directory: lib/hub/single
  $P.Bundled:
    directory: lib/hub/bundled
    bundle: true
modules:
  - name: lookalike
    subdirectories: true
EOF
cat > "$reg/$E/flatpark.yml" <<EOF
id: $E
name: Foo
summary: Synthetic extension
source_url: https://github.com/example/foo
build:
  manifest: $E.yml
  extends: $P
policy:
  proprietary: false
EOF
manifest() {   # <sdk-version> [extra lines...]
    printf 'id: %s\nruntime: %s\nruntime-version: stable\nsdk: org.gnome.Sdk//%s\nbuild-extension: true\n' "$E" "$P" "$1"
    printf 'modules:\n  - name: foo\n    sources:\n      - type: extra-data\n        filename: f\n        url: https://example.org/f\n        sha256: aaaa\n        size: 1\n'
}
manifest 51 > "$reg/$E/$E.yml"
touch "$reg/$E/$E.svg"
audit() { node "$tmp/scripts/audit-descriptor.mjs" "$reg/$E/flatpark.yml" 2>&1; }
rejects() {    # <text the failure must carry>
    local out rc
    out="$(audit)"; rc=$?
    assert_eq "$rc" "1"
    printf '%s' "$out" | grep -qF "$1" || { echo "FAIL: audit did not report [$1]: $out"; exit 1; }
}

audit >/dev/null || { echo "FAIL: a sound extension was rejected"; audit; exit 1; }

manifest 50 > "$reg/$E/$E.yml"; rejects "differs from"
{ manifest 51; printf 'finish-args:\n  - --share=network\n'; } > "$reg/$E/$E.yml"; rejects "no finish-args"
manifest 51 | sed '/type: extra-data/,$d' > "$reg/$E/$E.yml"; rejects "as extra-data"
{ manifest 51; printf '      - type: archive\n        url: https://example.org/a\n        sha256: bbbb\n'; } > "$reg/$E/$E.yml"; rejects "archive source"
manifest 51 | sed "s/^runtime: .*/runtime: org.gnome.Platform/" > "$reg/$E/$E.yml"; rejects "runtime must be"
manifest 51 | sed '/^build-extension/d' > "$reg/$E/$E.yml"; rejects "needs build-extension"
manifest 51 > "$reg/$E/$E.yml"
sed -i "s/  extends: .*/  extends: io.flatpark.Missing/" "$reg/$E/flatpark.yml"; rejects "not in the registry"
sed -i "/  extends: /d" "$reg/$E/flatpark.yml"; rejects "needs build.extends"
sed -i "s/^  manifest: .*/&\n  extends: $P/" "$reg/$E/flatpark.yml"
# Only a point that takes subdirectories covers a longer id, and only under add-extensions.
sed -i "s/^id: .*/id: $P.Single.Foo/" "$reg/$E/flatpark.yml"; rejects "no extension point"
sed -i "s/^id: .*/id: $P.modules.Foo/" "$reg/$E/flatpark.yml"; rejects "no extension point"
sed -i "s/^id: .*/id: $E/" "$reg/$E/flatpark.yml"

meta="$(node "$tmp/scripts/read-extension-points.mjs" "$reg/$P/$P.yml" x86_64)"
printf '%s\n' "$meta" > "$tmp/meta"
assert_contains "$tmp/meta" "runtime=org.gnome.Platform/x86_64/51"
assert_contains "$tmp/meta" "sdk=org.gnome.Sdk/x86_64/51"
assert_contains "$tmp/meta" "command=hub"
assert_contains "$tmp/meta" "[Extension $P.Driver]"
assert_contains "$tmp/meta" "directory=lib/hub/extensions"
assert_contains "$tmp/meta" "subdirectories=true"
assert_contains "$tmp/meta" "[Extension $P.Single]"
if grep -q lookalike "$tmp/meta"; then echo "FAIL: a key outside add-extensions leaked"; exit 1; fi

env_common=(OUT_DIR="$tmp/out" GNUPGHOME_DIR="$tmp/gnupg" REPO_URL="file://$tmp/out/repo" REGISTRY_DIR="$reg")

# The stand-in goes into the user installation only when the parent isn't
# there, and leaves with the build: a stub left behind would shadow a parent
# installed with --system. A fake flatpak answers the parent's origin.
mkdir -p "$tmp/fake"
cat > "$tmp/fake/flatpak" <<'FAKE'
#!/bin/sh
echo "$*" >> "$FAKE_LOG"
case "$*" in
    *--show-origin*) [ -n "$FAKE_ORIGIN" ] && echo "$FAKE_ORIGIN" ;;
    --default-arch) echo x86_64 ;;
esac
exit 0
FAKE
chmod +x "$tmp/fake/flatpak"
skeleton() {   # <origin of the installed parent, or empty> [--remove]
    : > "$tmp/flatpak.log"
    env "${env_common[@]}" PATH="$tmp/fake:$PATH" FAKE_LOG="$tmp/flatpak.log" FAKE_ORIGIN="$1" \
        "$tmp/scripts/install-parent-skeleton.sh" ${2-} "$P" >/dev/null 2>&1
    grep -E -- '--user (install|uninstall)' "$tmp/flatpak.log" | grep -F "$P" | awk '{print $2}' | paste -sd' '
}
assert_eq "$(skeleton "")" "install"
assert_eq "$(skeleton flatpark-skeleton)" "install"
assert_eq "$(skeleton flatpark)" ""
assert_eq "$(skeleton flatpark-skeleton --remove)" "uninstall"
assert_eq "$(skeleton flatpark --remove)" ""
assert_eq "$(skeleton "" --remove)" ""
env "${env_common[@]}" "$tmp/scripts/gen-signing-key.sh" >/dev/null 2>&1
env "${env_common[@]}" "$tmp/scripts/gen-discovery.sh" "$E" 2>/dev/null
env "${env_common[@]}" "$tmp/scripts/gen-discovery.sh" "$P" 2>/dev/null
assert_contains "$tmp/out/$E.flatpakref" "IsRuntime=true"
assert_contains "$tmp/out/$P.flatpakref" "IsRuntime=false"

# A parent's runtime move, or its removal, lists its extensions.
git -C "$tmp" init -q
g() { git -C "$tmp" -c user.name=t -c user.email=t@example.org -c commit.gpgsign=false "$@"; }
g add -A; g commit -qm base
changed() { "$tmp/scripts/changed-apps.sh" "$@" HEAD~1 HEAD 2>/dev/null | sort | paste -sd' '; }
sed -i 's/^command: hub/command: hubby/' "$reg/$P/$P.yml"; g add -A; g commit -qm "no move"
assert_eq "$(changed)" "$P"
# Only build.extends names a parent; the same key elsewhere doesn't.
mkdir -p "$reg/io.flatpark.Decoy"
printf 'id: io.flatpark.Decoy\nbuild:\n  manifest: d.yml\ncatalog:\n  extends: %s\n' "$P" > "$reg/io.flatpark.Decoy/flatpark.yml"
sed -i 's/^runtime-version: .*/runtime-version: "52"/' "$reg/$P/$P.yml"; g add "$reg/$P"; g commit -qm move
assert_eq "$(changed)" "$P $E"
rm -r "$reg/io.flatpark.Decoy"
assert_eq "$(changed --any-change)" "$P $E"
assert_eq "$(node "$tmp/scripts/audit-descriptor.mjs" "$reg/$E/flatpark.yml" 2>&1 | grep -c 'differs from')" "1"
sed -i 's/^runtime-version: .*/runtime-version: "51"/' "$reg/$P/$P.yml"; g add -A; g commit -qm back
mv "$reg/$P" "$tmp/parent"; g add -A; g commit -qm delist
assert_eq "$(changed --any-change)" "$E"
mv "$tmp/parent" "$reg/$P"; g add -A; g commit -qm restore
# The parent's manifest is found through its descriptor, and an sdk move counts.
g mv "registry/$P/$P.yml" "registry/$P/hub.yml"
sed -i 's/^  manifest: .*/  manifest: hub.yml/' "$reg/$P/flatpark.yml"; g add -A; g commit -qm rename
sed -i 's/^sdk: .*/sdk: org.gnome.Sdk.Next/' "$reg/$P/hub.yml"; g add -A; g commit -qm sdk
assert_eq "$(changed)" "$P $E"
sed -i 's/^sdk: .*/sdk: org.gnome.Sdk/' "$reg/$P/hub.yml"
g mv "registry/$P/hub.yml" "registry/$P/$P.yml"
sed -i "s/^  manifest: .*/  manifest: $P.yml/" "$reg/$P/flatpark.yml"; g add -A; g commit -qm unrename

if command -v ostree >/dev/null; then
    repo="$tmp/repo"; ostree --repo="$repo" init --mode=archive-z2
    commit() { rm -rf "$tmp/t"; mkdir -p "$tmp/t/files"; printf '%s\n' "$2" > "$tmp/t/metadata"
        ostree --repo="$repo" commit --branch="$1" --subject=t "$tmp/t" >/dev/null; }
    of() { printf '[Runtime]\nname=x\n\n[ExtensionOf]\nref=%s\n' "$1"; }
    commit "runtime/$E/x86_64/stable" "$(of "app/$P/x86_64/stable")"
    commit "runtime/$P.Driver.Gone/x86_64/stable" "$(of "app/$P/x86_64/stable")"
    commit "runtime/$P.Bundled/x86_64/stable" "$(of "app/$P/x86_64/stable")"
    commit "runtime/gone.Hub.Driver.Foo/x86_64/stable" "$(of "app/gone.Hub/x86_64/stable")"
    commit "runtime/org.example.Platform.GL.foo/x86_64/1" "$(of "runtime/org.example.Platform/x86_64/50")"
    commit "runtime/org.example.Platform/x86_64/50" "[Runtime]"
    env "${env_common[@]}" "$tmp/scripts/prune-and-reclaim.sh" "$repo" >/dev/null 2>&1
    assert_eq "$(ostree --repo="$repo" refs | sort | paste -sd' ')" \
        "runtime/$P.Bundled/x86_64/stable runtime/$E/x86_64/stable runtime/org.example.Platform.GL.foo/x86_64/1 runtime/org.example.Platform/x86_64/50"
    # A parent whose manifest can't be read: keep, don't guess.
    commit "runtime/$P.Driver.Gone/x86_64/stable" "$(of "app/$P/x86_64/stable")"
    mv "$reg/$P/$P.yml" "$tmp/parent.yml"
    env "${env_common[@]}" "$tmp/scripts/prune-and-reclaim.sh" "$repo" >/dev/null 2>&1
    mv "$tmp/parent.yml" "$reg/$P/$P.yml"
    assert_eq "$(ostree --repo="$repo" refs | grep -c "^runtime/$P.Driver.Gone/")" "1"
fi

if [ -d "$ROOT/site/node_modules/yaml" ]; then
    data="$tmp/data"
    git -C "$reg" init -q; git -C "$reg" add -A
    git -C "$reg" -c user.name=t -c user.email=t@example.org -c commit.gpgsign=false commit -qm reg
    REGISTRY_DIR="$reg" DATA_DIR="$data" "$tmp/scripts/gen-apps-json.sh" 2>/dev/null
    ( cd "$ROOT/site" && FLATPARK_DATA_DIR="$data" FLATPARK_STATS_URL= node tools/enrich.mjs >/dev/null 2>&1 )
    out="$data/apps/$E.json"
    assert_contains "$out" '"label": "Network access"'
    assert_contains "$out" "\"id\": \"$P\""
    assert_contains "$out" "flatpak install flatpark $P"
    grep -q '"runtime": "org.gnome.Platform"' "$out" || { echo "FAIL: page runtime is not the parent's"; exit 1; }

    # With the parent gone the page can't be honest, so the build stops.
    REGISTRY_DIR="$reg" DATA_DIR="$data" "$tmp/scripts/gen-apps-json.sh" 2>/dev/null
    rm -rf "$reg/$P"
    if ( cd "$ROOT/site" && FLATPARK_DATA_DIR="$data" FLATPARK_STATS_URL= node tools/enrich.mjs >/dev/null 2>&1 ); then
        echo "FAIL: enrich accepted an extension whose parent is gone"; exit 1
    fi
fi
echo "test_extensions: PASS"
