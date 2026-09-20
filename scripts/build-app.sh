#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
load_app "${1:?usage: build-app.sh <app-id>}"
need flatpak; need gpg
need_flatpak_builder
export GNUPGHOME="$GNUPGHOME_DIR"
[ -f "$MANIFEST" ] || die "manifest not found: $MANIFEST"
fpr="$(gpg --list-keys --with-colons "$KEY_EMAIL" | awk -F: '/^fpr:/{print $10; exit}')"
[ -n "$fpr" ] || die "no signing key (run gen-signing-key.sh)"
mkdir -p "$OUT_DIR"
build_dir="$OUT_DIR/build-$APP_ID"
state_dir="$OUT_DIR/flatpak-builder-state"
# Every path the builder touches has to be reachable from inside its sandbox.
assert_builder_visible "$MANIFEST" "$OUT_DIR" "$GNUPGHOME_DIR" "$REPO_DIR"

args=(--force-clean --repo="$REPO_DIR" --default-branch="$APP_BRANCH"
      --state-dir="$state_dir"
      --gpg-sign="$fpr" --gpg-homedir="$GNUPGHOME_DIR")
# rofiles-fuse needs /dev/fuse and a mount; the sandboxed builder has neither,
# and the host's /dev/fuse says nothing about what is inside the sandbox. On the
# host it stays the optimization it always was.
if have_host_flatpak_builder; then
    [ -e /dev/fuse ] || args+=(--disable-rofiles-fuse)
else
    args+=(--disable-rofiles-fuse)
fi
if [ -n "${RUNTIME_REPO_URL:-}" ]; then
    flatpak --user remote-add --if-not-exists --from "$RUNTIME_REMOTE_NAME" "$RUNTIME_REPO_URL" || true
    args+=(--install-deps-from="$RUNTIME_REMOTE_NAME" --user)
fi

flatpak_builder --cwd="$APP_SRC" --env=GNUPGHOME="$GNUPGHOME_DIR" -- \
    "${args[@]}" "$build_dir" "$MANIFEST"
log "built $APP_ID into $REPO_DIR"
