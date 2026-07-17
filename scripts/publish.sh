#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
verify=0
requested_apps=()
for arg in "$@"; do
    case "$arg" in
        --verify) verify=1 ;;
        *) requested_apps+=("$arg") ;;
    esac
done

apps=()
while IFS= read -r app_id; do
    apps+=("$app_id")
done < <("$ROOT/scripts/scan-registry.sh" --ids "${requested_apps[@]}")
[ "${#apps[@]}" -gt 0 ] || die "registry scan returned no apps"

"$ROOT/scripts/gen-signing-key.sh" >/dev/null
for app_id in "${apps[@]}"; do
    "$ROOT/scripts/build-app.sh" "$app_id"
done
"$ROOT/scripts/publish-repo.sh"
for app_id in "${apps[@]}"; do
    "$ROOT/scripts/gen-discovery.sh" "$app_id"
done
"$ROOT/scripts/gen-site.sh" "${apps[@]}"
log "publish complete -> $OUT_DIR"

if [ "$verify" = "1" ]; then
    need flatpak
    remote="$VERIFY_REMOTE_NAME"
    [ "$remote" != "$REMOTE_NAME" ] ||
        die "VERIFY_REMOTE_NAME ($remote) must differ from REMOTE_NAME so --verify never touches the real remote"
    remote_url="file://$REPO_DIR"

    # If an app under verify is already installed (e.g. from the real remote),
    # remember its origin: --reinstall moves it to the verify remote, and
    # cleanup puts it back where it came from.
    declare -A verify_prev_origin=()
    for app_id in "${apps[@]}"; do
        prev="$(flatpak --user info --show-origin "$app_id" 2>/dev/null || true)"
        if [ -n "$prev" ] && [ "$prev" != "$remote" ]; then
            verify_prev_origin["$app_id"]="$prev"
        fi
    done

    verify_cleanup() {
        local app_id origin
        for app_id in "${apps[@]}"; do
            origin="$(flatpak --user info --show-origin "$app_id" 2>/dev/null || true)"
            [ "$origin" = "$remote" ] || continue
            flatpak --user uninstall -y "$app_id" >/dev/null 2>&1 ||
                warn "verify cleanup: could not uninstall $app_id"
            if [ -n "${verify_prev_origin[$app_id]-}" ]; then
                if flatpak --user install -y "${verify_prev_origin[$app_id]}" "$app_id" >/dev/null 2>&1; then
                    log "verify cleanup: restored $app_id from ${verify_prev_origin[$app_id]}"
                else
                    warn "verify cleanup: could not restore $app_id — run: flatpak --user install ${verify_prev_origin[$app_id]} $app_id"
                fi
            fi
        done
        flatpak --user remote-delete --force "$remote" >/dev/null 2>&1 ||
            warn "verify cleanup: could not delete remote $remote"
        log "verify: removed temporary remote $remote"
    }
    if [ "${FLATPARK_VERIFY_KEEP:-0}" = "1" ]; then
        log "verify: FLATPARK_VERIFY_KEEP=1 — leaving remote $remote and installed apps in place"
    else
        trap verify_cleanup EXIT
    fi

    remote_args=(--title="$REPO_TITLE" --comment="$REPO_COMMENT"
        --homepage="$REPO_HOMEPAGE" --gpg-import="$PUBKEY_FILE")
    if flatpak --user remotes | awk '{print $1}' | grep -qxF "$remote"; then
        flatpak --user remote-modify --url="$remote_url" "${remote_args[@]}" "$remote"
    else
        flatpak --user remote-add "${remote_args[@]}" "$remote" "$remote_url"
    fi
    for app_id in "${apps[@]}"; do
        flatpak --user install -y --reinstall "$remote" "$app_id"
        log "verify: installed $app_id from local signed repo OK"
    done
fi
