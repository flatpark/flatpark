#!/usr/bin/env bash
# Install a stand-in for an extension's parent app: the metadata its registry
# manifest describes and the extension points' folders, nothing else.
#
# flatpak-builder needs the parent installed to read the extension point and the
# runtime, and looks for it on Flathub, where a FlatPark app isn't. Installing the
# real one would fetch all of its extra-data on every build, and would describe
# what is published, not this commit: a parent changing runtime would build its
# extensions against the old one. The stand-in stays out of the published repo.
#
# It has to be in the user installation: with --install-deps-from and --user,
# flatpak-builder looks for the parent there and nowhere else. It is there only
# for the build: build-app.sh runs `--remove` when it ends, or the stub would
# shadow a real parent installed with --system (`flatpak run` prefers the user
# installation). A parent already in the user installation is used as it is.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need flatpak; need node
remove=0
[ "${1-}" = "--remove" ] && { remove=1; shift; }
parent="${1:?usage: install-parent-skeleton.sh [--remove] <parent-id>}"
load_app "$parent"
remote="$REMOTE_NAME-skeleton"
origin="$(flatpak --user info --show-origin "$parent" 2>/dev/null || true)"
if [ "$remove" = 1 ]; then
    flatpak --user remote-delete --force "$remote" >/dev/null 2>&1 || true
    [ "$origin" = "$remote" ] || exit 0
    flatpak --user uninstall -y --noninteractive "$parent" >/dev/null
    log "removed the stand-in for $parent"
    exit 0
fi
[ -z "$origin" ] || [ "$origin" = "$remote" ] || exit 0

mkdir -p "$OUT_DIR"
work="$(mktemp -d -p "$OUT_DIR")"; trap 'rm -rf "$work"' EXIT
mkdir -p "$work/app/files/bin" "$work/app/export"
node "$ROOT/scripts/read-extension-points.mjs" "$MANIFEST" "$(flatpak --default-arch)" > "$work/app/metadata"
sed -n 's/^directory=//p' "$work/app/metadata" | while IFS= read -r dir; do
    mkdir -p "$work/app/files/$dir"
done
command="$(sed -n 's/^command=//p' "$work/app/metadata")"
printf '#!/bin/sh\n' > "$work/app/files/bin/$command"
chmod +x "$work/app/files/bin/$command"

flatpak build-export "$work/repo" "$work/app" "$APP_BRANCH" >/dev/null
flatpak --user remote-add --no-gpg-verify "$remote" "file://$work/repo"
flatpak --user install -y --noninteractive --no-deps --reinstall "$remote" "$parent"
flatpak --user remote-delete --force "$remote"
# --no-deps above: the stand-in's repo has no runtime, and check-apply-extra needs it.
[ -z "${RUNTIME_REPO_URL:-}" ] || flatpak --user install -y --noninteractive "$RUNTIME_REMOTE_NAME" \
    "runtime/$(sed -n 's/^runtime=//p' "$work/app/metadata")"
log "installed a stand-in for $parent"
