#!/usr/bin/env bash
# A shared extension (build.shared) and the apps that use it: the descriptor,
# the audit of the extension and of its users (flatpark-spawn's allow-list,
# config/flatpark-spawn.yml), the stand-in it builds against, discovery,
# change detection, the delist, and the site data.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v git >/dev/null || { echo "test_shared_extensions: SKIP (no git)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# The audit reads the allow-list next to its own scripts, so the test works on
# a copy of both.
cp -r "$ROOT/scripts" "$ROOT/config" "$tmp/"
reg="$tmp/registry"; E=org.flatpark.Spawn; C=com.example.Consumer
mkdir -p "$reg"
cp -r "$ROOT/tests/fixtures/shared/$E" "$ROOT/tests/fixtures/shared/$C" "$reg/"
allow() { printf 'apps:\n%s' "$(for id in "$@"; do printf '  - %s  # test\n' "$id"; done)" > "$tmp/config/flatpark-spawn.yml"; }
allow
fresh() { rm -rf "${reg:?}/$1"; cp -r "$ROOT/tests/fixtures/shared/$1" "$reg/"; }

audit() { node "$tmp/scripts/audit-descriptor.mjs" "$reg/$1/flatpark.yml" 2>&1; }
passes() {     # <id>
    audit "$1" >/dev/null || { echo "FAIL: audit rejected a sound $1"; audit "$1"; exit 1; }
}
rejects() {    # <id> <text the failure must carry>
    local out rc
    out="$(audit "$1")"; rc=$?
    assert_eq "$rc" "1"
    printf '%s' "$out" | grep -F "FAIL:" | grep -qF -- "$2" || { echo "FAIL: audit of $1 did not report [$2]: $out"; exit 1; }
}

# --- The descriptor -------------------------------------------------------
desc="$(node "$tmp/scripts/read-descriptor.mjs" "$reg/$E/flatpark.yml")"
printf '%s\n' "$desc" > "$tmp/desc"
assert_contains "$tmp/desc" "_FP_SHARED='true'"
assert_contains "$tmp/desc" "_FP_EXTENDS=''"
node "$tmp/scripts/read-descriptor.mjs" "$reg/$C/flatpark.yml" > "$tmp/desc"
assert_contains "$tmp/desc" "_FP_SHARED=''"
got="$( . "$tmp/scripts/lib/common.sh"; REGISTRY_DIR="$reg" load_config "$tmp"; load_app "$E"
        printf '%s|%s|%s' "$APP_SHARED" "$APP_BUILD_PARENT" "$APP_EXTENDS" )"
assert_eq "$got" "true|$reg/$E/$E.BuildParent.yml|"
got="$( . "$tmp/scripts/lib/common.sh"; REGISTRY_DIR="$reg" load_config "$tmp"; load_app "$C"
        printf '%s|%s' "$APP_SHARED" "$APP_BUILD_PARENT" )"
assert_eq "$got" "|"
# Exclusive with a parent, and a boolean.
sed 's/^  shared: true/&\n  extends: com.example.Hub/' "$reg/$E/flatpark.yml" > "$tmp/both.yml"
if node "$tmp/scripts/read-descriptor.mjs" "$tmp/both.yml" >/dev/null 2>&1; then
    echo "FAIL: read-descriptor accepted build.shared with build.extends"; exit 1
fi
sed 's/^  shared: true/  shared: yes/' "$reg/$E/flatpark.yml" > "$tmp/yes.yml"
if node "$tmp/scripts/read-descriptor.mjs" "$tmp/yes.yml" >/dev/null 2>&1; then
    echo "FAIL: read-descriptor accepted build.shared: yes"; exit 1
fi

# --- Audit: the shared extension ------------------------------------------
passes "$E"
sed -i 's/^  shared: true/&\n  extends: com.example.Hub/' "$reg/$E/flatpark.yml"; rejects "$E" "exclude each other"; fresh "$E"
sed -i 's/^  shared: true/  shared: yes/' "$reg/$E/flatpark.yml"; rejects "$E" "build.shared must be true or false"; fresh "$E"
sed -i '/^  shared: true/d' "$reg/$E/flatpark.yml"; rejects "$E" "needs build.extends (or build.shared)"; fresh "$E"
rm "$reg/$E/$E.BuildParent.yml"; rejects "$E" "the stand-in $E.BuildParent.yml is missing"; fresh "$E"
sed -i '/^add-extensions:/,/^modules:/{/^add-extensions:/d;/^  /d}' "$reg/$E/$E.BuildParent.yml"
rejects "$E" "declares no extension point $E"; fresh "$E"
sed -i 's/^  org.flatpark.Spawn:/  org.flatpark.Other:/' "$reg/$E/$E.BuildParent.yml"
rejects "$E" "declares no extension point $E"; fresh "$E"
sed -i "s/^runtime-version: .*/runtime-version: '25.08'/" "$reg/$E/$E.BuildParent.yml"
rejects "$E" "sdk version 26.08 differs from the stand-in's runtime 25.08"; fresh "$E"
sed -i 's#^sdk: .*#sdk: org.freedesktop.Sdk//25.08#' "$reg/$E/$E.yml"
rejects "$E" "sdk version 25.08 differs"; fresh "$E"
sed -i '/mkdir -p/d' "$reg/$E/$E.BuildParent.yml"; rejects "$E" "has to mkdir -p /app/lib/flatpark-spawn"; fresh "$E"
sed -i "s/^    version: '1'/    version: '2'/" "$reg/$E/$E.BuildParent.yml"; rejects "$E" "with version 2"; fresh "$E"
sed -i 's/^app-id: .*/app-id: org.example.Stub/' "$reg/$E/$E.BuildParent.yml"; rejects "$E" "must have app-id $E.BuildParent"; fresh "$E"
sed -i 's/^runtime: .*/runtime: org.freedesktop.Platform/' "$reg/$E/$E.yml"; rejects "$E" "runtime must be the stand-in"; fresh "$E"
sed -i 's/^runtime-version: .*/runtime-version: stable/' "$reg/$E/$E.yml"; rejects "$E" "runtime-version must be master"; fresh "$E"
sed -i '/^build-extension/d' "$reg/$E/$E.yml"; rejects "$E" "needs build-extension: true"; fresh "$E"
printf 'finish-args:\n  - --share=network\n' >> "$reg/$E/$E.yml"; rejects "$E" "no finish-args"; fresh "$E"
sed -i 's/type: extra-data/type: archive/' "$reg/$E/$E.yml"; rejects "$E" "as extra-data"; fresh "$E"
mkdir -p "$reg/$E.BuildParent"; printf 'id: %s.BuildParent\n' "$E" > "$reg/$E.BuildParent/flatpark.yml"
rejects "$E" "a stand-in is never published"; rm -r "$reg/$E.BuildParent"
passes "$E"

# --- Audit: an app that uses flatpark-spawn (SPEC 2.2) --------------------
rejects "$C" "not on the allow-list (config/flatpark-spawn.yml)"
allow "$C"
passes "$C"
breaks() {     # <file> <sed expression> <text the failure must carry>
    sed -i "$2" "$reg/$C/$1"; rejects "$C" "$3"; fresh "$C"
}
breaks "$C.yml" '/^  - --talk-name=org.freedesktop.Flatpak/d' "needs --talk-name=org.freedesktop.Flatpak in finish-args"
breaks flatpark.yml '/^  dangerous_permissions:/,/^packaging:/{/^    - /d}' "must be declared in policy.dangerous_permissions"
breaks flatpark.yml '/^packaging:/,$d' 'needs a "host-command" entry'
breaks "$C.yml" "s/^    version: '1'/&\n    autodelete: true/" "can't have autodelete: true"
breaks "$C.yml" "s/^    version: '1'/&\n    no-autodownload: true/" "can't have no-autodownload: true"
breaks "$C.yml" "s/^    version: '1'/    version: '2'/" "needs version: '1'"
breaks "$C.yml" '/^    version:/d' "needs version: '1'"
breaks "$C.yml" 's#^    directory: lib/flatpark-spawn#    directory: lib/spawn#' "needs directory: lib/flatpark-spawn"
breaks "$C.yml" '/mkdir -p/d' "mkdir -p /app/lib/flatpark-spawn"
# autodelete: false is the documented way to say it out loud.
sed -i "s/^    version: '1'/&\n    autodelete: false/" "$reg/$C/$C.yml"; passes "$C"; fresh "$C"
# Bundling flatpark-spawn, or reaching for it without the extension point, is
# using it all the same.
breaks "$C.yml" '/^add-extensions:/,/^modules:/{/^add-extensions:/d;/^  /d}' "doesn't declare $E under add-extensions"
# Off the allow-list again: every way of using it fails.
allow
sed -i '/^add-extensions:/,/^modules:/{/^add-extensions:/d;/^  /d}' "$reg/$C/$C.yml"
rejects "$C" "not on the allow-list"
fresh "$C"
# On the allow-list without using it yet: a warning, so the grant can land first.
allow "$C"
sed -i '/^add-extensions:/,/^modules:/{/^add-extensions:/d;/^  /d}' "$reg/$C/$C.yml"
rm "$reg/$C/consumer-wrapper"; sed -i '/mkdir -p/d; /consumer-wrapper/d; /type: file/d' "$reg/$C/$C.yml"
out="$(audit "$C")"; rc=$?
assert_eq "$rc" "0"
printf '%s' "$out" | grep -qF "WARN: $C is on the flatpark-spawn allow-list" || { echo "FAIL: listed app without the extension not warned: $out"; exit 1; }
fresh "$C"
# The allow-list reader takes a block list with comments, and an inline one.
printf '# c\napps:\n  - a.B   # flatpark#1\n  # - c.D\n  - "e.F"\nother:\n  - g.H\n' > "$tmp/list.yml"
assert_eq "$(node "$tmp/scripts/flatpark-spawn.mjs" "$tmp/list.yml" | paste -sd' ')" "a.B e.F"
printf 'apps: [a.B, e.F]\n' > "$tmp/list.yml"
assert_eq "$(node "$tmp/scripts/flatpark-spawn.mjs" "$tmp/list.yml" | paste -sd' ')" "a.B e.F"
assert_eq "$(node "$ROOT/scripts/flatpark-spawn.mjs" "$ROOT/config/flatpark-spawn.yml" | wc -l)" "0"

# --- The stand-in --------------------------------------------------------
meta="$(node "$tmp/scripts/read-extension-points.mjs" "$reg/$E/$E.BuildParent.yml" x86_64)"
printf '%s\n' "$meta" > "$tmp/meta"
assert_contains "$tmp/meta" "name=$E.BuildParent"
assert_contains "$tmp/meta" "runtime=org.freedesktop.Platform/x86_64/26.08"
assert_contains "$tmp/meta" "[Extension $E]"
assert_contains "$tmp/meta" "directory=lib/flatpark-spawn"
assert_eq "$(node "$tmp/scripts/read-extension-points.mjs" --branch "$reg/$E/$E.BuildParent.yml")" "master"

env_common=(OUT_DIR="$tmp/out" GNUPGHOME_DIR="$tmp/gnupg" REPO_URL="file://$tmp/out/repo" REGISTRY_DIR="$reg")
# A fake flatpak answers the stand-in's origin and logs the rest; a fake
# flatpak-builder records what it was asked to build.
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
cat > "$tmp/fake/flatpak-builder" <<'FAKE'
#!/bin/sh
echo "builder $*" >> "$FAKE_LOG"
exit 0
FAKE
chmod +x "$tmp/fake/flatpak" "$tmp/fake/flatpak-builder"
skeleton() {   # <origin of the installed stand-in, or empty> [--remove]
    : > "$tmp/flatpak.log"
    env "${env_common[@]}" PATH="$tmp/fake:$PATH" FAKE_LOG="$tmp/flatpak.log" FAKE_ORIGIN="$1" \
        "$tmp/scripts/install-parent-skeleton.sh" ${2-} --manifest "$reg/$E/$E.BuildParent.yml" >/dev/null 2>&1
    grep -E -- '--user (install|uninstall)' "$tmp/flatpak.log" | grep -F "$E.BuildParent" | awk '{print $2}' | paste -sd' '
}
assert_eq "$(skeleton "")" "install"
assert_eq "$(skeleton flatpark-skeleton --remove)" "uninstall"
assert_eq "$(skeleton flatpark --remove)" ""
# It is exported on the stand-in's branch, into a throwaway repo, never $REPO_DIR.
skeleton "" >/dev/null
grep -E '^build-export ' "$tmp/flatpak.log" > "$tmp/export.log"
assert_contains "$tmp/export.log" " master"
if grep -qF "$tmp/out/repo" "$tmp/export.log"; then echo "FAIL: the stand-in was exported to the published repo"; exit 1; fi
# build-app.sh installs it from the descriptor, builds, and removes it.
env "${env_common[@]}" "$tmp/scripts/gen-signing-key.sh" >/dev/null 2>&1
: > "$tmp/flatpak.log"
env "${env_common[@]}" PATH="$tmp/fake:$PATH" FAKE_LOG="$tmp/flatpak.log" FAKE_ORIGIN="" \
    "$tmp/scripts/build-app.sh" "$E" >/dev/null 2>&1 || { echo "FAIL: build-app.sh failed for a shared extension"; exit 1; }
assert_eq "$(grep -E -- '--user install' "$tmp/flatpak.log" | grep -cF "$E.BuildParent")" "1"
grep -F builder "$tmp/flatpak.log" | grep -qF "$reg/$E/$E.yml" || { echo "FAIL: build-app.sh did not build the extension's manifest"; exit 1; }
rm "$reg/$E/$E.BuildParent.yml"
if env "${env_common[@]}" PATH="$tmp/fake:$PATH" FAKE_LOG="$tmp/flatpak.log" FAKE_ORIGIN="" \
        "$tmp/scripts/build-app.sh" "$E" >/dev/null 2>&1; then
    echo "FAIL: build-app.sh built a shared extension without its stand-in"; exit 1
fi
fresh "$E"

# --- Discovery -------------------------------------------------------------
env "${env_common[@]}" "$tmp/scripts/gen-discovery.sh" "$E" 2>/dev/null
env "${env_common[@]}" "$tmp/scripts/gen-discovery.sh" "$C" 2>/dev/null
assert_contains "$tmp/out/$E.flatpakref" "IsRuntime=true"
assert_contains "$tmp/out/$E.flatpakref" "Branch=1"
assert_contains "$tmp/out/$C.flatpakref" "IsRuntime=false"

# --- Change detection --------------------------------------------------------
git -C "$tmp" init -q
g() { git -C "$tmp" -c user.name=t -c user.email=t@example.org -c commit.gpgsign=false "$@"; }
g add -A; g commit -qm base
changed() { "$tmp/scripts/changed-apps.sh" "$@" HEAD~1 HEAD 2>/dev/null | sort | paste -sd' '; }
# An app that uses it moving runtime, or leaving, doesn't rebuild it.
sed -i "s/^runtime-version: .*/runtime-version: '27.08'/" "$reg/$C/$C.yml"; g add -A; g commit -qm move
assert_eq "$(changed)" "$C"
mv "$reg/$C" "$tmp/consumer"; g add -A; g commit -qm delist
assert_eq "$(changed --any-change)" ""
mv "$tmp/consumer" "$reg/$C"; g add -A; g commit -qm restore
# Its stand-in is one of its own files: a change rebuilds it.
sed -i "s/^runtime-version: .*/runtime-version: '27.08'/" "$reg/$E/$E.BuildParent.yml"; g add -A; g commit -qm standin
assert_eq "$(changed)" "$E"
assert_eq "$( . "$tmp/scripts/lib/common.sh"; REGISTRY_DIR="$reg" load_config "$tmp"; extensions_of "$E.BuildParent"; extensions_of "$C" )" ""

# --- Delist ----------------------------------------------------------------
if command -v ostree >/dev/null; then
    repo="$tmp/repo"; ostree --repo="$repo" init --mode=archive-z2
    commit() { rm -rf "$tmp/t"; mkdir -p "$tmp/t/files"; printf '%s\n' "$2" > "$tmp/t/metadata"
        ostree --repo="$repo" commit --branch="$1" --subject=t "$tmp/t" >/dev/null; }
    of() { printf '[Runtime]\nname=x\n\n[ExtensionOf]\nref=app/%s.BuildParent/x86_64/master\nruntime=org.freedesktop.Platform/x86_64/26.08\n' "$1"; }
    commit "runtime/$E/x86_64/1" "$(of "$E")"
    commit "runtime/org.flatpark.Gone/x86_64/1" "$(of org.flatpark.Gone)"
    env "${env_common[@]}" "$tmp/scripts/prune-and-reclaim.sh" "$repo" >/dev/null 2>&1
    # Listed, it stays though its stand-in is in no registry; delisted, it goes.
    assert_eq "$(ostree --repo="$repo" refs | sort | paste -sd' ')" "runtime/$E/x86_64/1"
fi

# --- Site data ---------------------------------------------------------------
if [ -d "$ROOT/site/node_modules/yaml" ]; then
    data="$tmp/data"
    git -C "$reg" init -q; git -C "$reg" add -A
    git -C "$reg" -c user.name=t -c user.email=t@example.org -c commit.gpgsign=false commit -qm reg
    REGISTRY_DIR="$reg" DATA_DIR="$data" "$tmp/scripts/gen-apps-json.sh" 2>/dev/null
    grep -q "\"installCmd\": \"flatpak install flatpark $E\"," "$data/apps/$E.json" \
        || { echo "FAIL: a shared extension's command names something besides it: $(grep installCmd "$data/apps/$E.json")"; exit 1; }
    ( cd "$ROOT/site" && FLATPARK_DATA_DIR="$data" FLATPARK_STATS_URL= node tools/enrich.mjs >/dev/null 2>&1 ) \
        || { echo "FAIL: enrich failed on a shared extension"; exit 1; }
    node -e '
      const fs = require("fs");
      const [dir, E, C] = process.argv.slice(1);
      const ext = JSON.parse(fs.readFileSync(`${dir}/${E}.json`, "utf8"));
      const app = JSON.parse(fs.readFileSync(`${dir}/${C}.json`, "utf8"));
      const want = (ok, what) => { if (!ok) { console.log(`FAIL: ${what}`); process.exit(1); } };
      want(ext.section === "extensions", `shared extension filed under ${ext.section}`);
      want(ext.shared === true && !ext.parent, "shared extension has a parent");
      want(ext.permissions.length === 0, "shared extension lists permissions");
      want(ext.runtime === "", `shared extension shows runtime ${ext.runtime}`);
      want(ext.hostCommands === true, "flatpark-spawn does not say it runs host commands");
      want(JSON.stringify(ext.consumers) === JSON.stringify([{ id: C, name: "Consumer" }]), `consumers ${JSON.stringify(ext.consumers)}`);
      want(ext.requires.length === 0, "shared extension requires a parent");
      want(app.section !== "extensions" && !app.shared, "the app using it became an extension");
      want(JSON.stringify(app.uses) === JSON.stringify([{ id: E, name: "flatpark-spawn" }]), `uses ${JSON.stringify(app.uses)}`);
      want(app.hostCommands === true, "the app using flatpark-spawn does not say it runs host commands");
      const talk = app.permissions.find((p) => p.value === "org.freedesktop.Flatpak");
      want(talk && talk.key === "talk_name.flatpark_spawn" && talk.level === "warning", `talk-name ${JSON.stringify(talk)}`);
    ' "$data/apps" "$E" "$C" || exit 1
fi
echo "test_shared_extensions: PASS"
