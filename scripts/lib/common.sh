#!/usr/bin/env bash
# Shared helpers for FlatPark publish tooling.
set -euo pipefail
log()  { printf '[flatpark] %s\n' "$*" >&2; }
warn() { printf '[flatpark] WARN: %s\n' "$*" >&2; }
die()  { printf '[flatpark] ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

# Two ways to run flatpak-builder, in this order:
#
#   1. A host `flatpak-builder` binary, when the machine has one. CI installs
#      it, because the sandboxed builder drives the build through the *host's*
#      flatpak over the session bus (a sandbox cannot nest another one) and a
#      headless runner has no bus it can reach — flatpak-spawn then fails,
#      the builder falls back to its bundled flatpak, and the first dependency
#      install dies with "Cannot autolaunch D-Bus without X11 $DISPLAY".
#   2. Otherwise the Flathub build of it, which is what a developer machine
#      uses: it carries the whole freedesktop SDK toolchain (bsdunzip,
#      appstreamcli, node, rpm2cpio, ...), so a manifest depends on that fixed
#      set instead of on whatever the distro happens to have installed.
#
# BUILDER_APP names the Flathub app; FLATPARK_FORCE_BUILDER_APP=1 skips the
# host binary even when one is installed (how you check locally what CI's
# counterpart would do, and the reverse of what CI does).
BUILDER_APP="${BUILDER_APP:-org.flatpak.Builder}"
have_host_flatpak_builder() {
    [ "${FLATPARK_FORCE_BUILDER_APP:-0}" = "1" ] && return 1
    command -v flatpak-builder >/dev/null 2>&1
}
have_builder_app() { flatpak info "$BUILDER_APP" >/dev/null 2>&1; }
need_flatpak_builder() {
    have_host_flatpak_builder && return 0
    need flatpak
    have_builder_app || die "no flatpak-builder: install the host package, or \
the Flathub app with 'flatpak install flathub $BUILDER_APP'"
}
# flatpak_builder [--cwd=DIR] [--env=VAR=VALUE]... -- [flatpak-builder arg...]
#
# The options are named after `flatpak run`'s because that is where they end up
# on the sandboxed path; the host path applies them itself.
flatpak_builder() {
    local cwd="" envs=() run_args=()
    while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
        case "$1" in
            --cwd=*) cwd="${1#--cwd=}" ;;
            --env=*) envs+=("${1#--env=}") ;;
            *)       run_args+=("$1") ;;
        esac
        shift
    done
    [ "${1-}" = "--" ] && shift
    if have_host_flatpak_builder; then
        ( [ -n "$cwd" ] && cd "$cwd"
          exec env ${envs[@]+"${envs[@]}"} flatpak-builder "$@" )
        return
    fi
    [ -n "$cwd" ] && run_args+=("--cwd=$cwd")
    local e
    for e in ${envs[@]+"${envs[@]}"}; do run_args+=("--env=$e"); done
    flatpak run "${run_args[@]}" --command=sh "$BUILDER_APP" -c "$_FLATPAK_BUILDER_SH" flatpak-builder "$@"
}
# Runs the app's own launcher (which is what wires up the host flatpak), then
# shuts down the gpg-agent that ostree starts to sign the commit: it daemonizes
# inside the sandbox, and `flatpak run` does not return while anything in there
# is still alive — the build would finish and then hang forever. Only ever the
# agent for the keyring the caller pointed GNUPGHOME at, never the user's own.
_FLATPAK_BUILDER_SH='
flatpak-builder-wrapper "$@"; rc=$?
[ -n "${GNUPGHOME:-}" ] && gpgconf --kill all >/dev/null 2>&1
exit $rc
'
# Only the sandboxed builder is affected: it gets --filesystem=host, which
# covers /home and other real mounts but not the directories the sandbox
# substitutes with its own. A path under one of those exists on the host and is
# simply absent inside, so say so here rather than let the builder fail with a
# confusing "file not found" halfway in.
assert_builder_visible() {
    have_host_flatpak_builder && return 0
    local p real
    for p in "$@"; do
        [ -n "$p" ] || continue
        real="$(realpath -m "$p")"
        case "$real" in
            /tmp|/tmp/*|/var/tmp|/var/tmp/*|/run/*|/root|/root/*)
                die "$BUILDER_APP cannot see $p: the sandbox replaces /tmp, /var/tmp, /run and /root with its own. Use a path under \$HOME or the repo (out/) instead." ;;
        esac
    done
}
load_config() {
    ROOT="$1"
    local conf="${FLATPARK_CONF:-$ROOT/config/flatpark.conf}"
    if [ "${_FLATPARK_CONFIG_LOADED:-0}" = "1" ]; then
        [ "${REPO_FILE_URL-}" = "${_FLATPARK_REPO_FILE_URL_DEFAULT-}" ] && unset REPO_FILE_URL
        [ "${REPO_DIR-}" = "${_FLATPARK_REPO_DIR_DEFAULT-}" ] && unset REPO_DIR
        [ "${PAGES_DIR-}" = "${_FLATPARK_PAGES_DIR_DEFAULT-}" ] && unset PAGES_DIR
        [ "${PUBKEY_FILE-}" = "${_FLATPARK_PUBKEY_FILE_DEFAULT-}" ] && unset PUBKEY_FILE
    fi
    [ -f "$conf" ] || die "missing config: $conf"
    # shellcheck disable=SC1090
    . "$conf"
    _FLATPARK_CONFIG_LOADED=1
    _FLATPARK_REPO_FILE_URL_DEFAULT="${REPO_URL%/}/flatpark.flatpakrepo"
    _FLATPARK_REPO_DIR_DEFAULT="$OUT_DIR/repo"
    _FLATPARK_PAGES_DIR_DEFAULT="$OUT_DIR/site"
    _FLATPARK_PUBKEY_FILE_DEFAULT="$OUT_DIR/flatpark.pub.asc"
    local var
    for var in ROOT REPO_TITLE REPO_HOMEPAGE REPO_COMMENT REPO_URL REPO_FILE_URL \
        RUNTIME_REPO_URL REMOTE_NAME RUNTIME_REMOTE_NAME VERIFY_REMOTE_NAME \
        REGISTRY_DIR PACKAGING_REPO_URL PACKAGING_BRANCH \
        GNUPGHOME_DIR KEY_NAME KEY_EMAIL OUT_DIR REPO_DIR PAGES_DIR PUBKEY_FILE \
        ; do
        declare -g "$var=${!var}"
    done
    declare -g "_FLATPARK_CONFIG_LOADED=$_FLATPARK_CONFIG_LOADED"
    declare -g "_FLATPARK_REPO_FILE_URL_DEFAULT=$_FLATPARK_REPO_FILE_URL_DEFAULT"
    declare -g "_FLATPARK_REPO_DIR_DEFAULT=$_FLATPARK_REPO_DIR_DEFAULT"
    declare -g "_FLATPARK_PAGES_DIR_DEFAULT=$_FLATPARK_PAGES_DIR_DEFAULT"
    declare -g "_FLATPARK_PUBKEY_FILE_DEFAULT=$_FLATPARK_PUBKEY_FILE_DEFAULT"
}

# The registry id an OSTree ref belongs to, or nothing for refs that are not
# per-app: appstream*, ostree-metadata, and runtimes we did not export from an
# app. Used to decide whether a ref is still backed by registry/<id>/.
ref_registry_id() {
    local ref="$1" id
    case "$ref" in
        app/*)
            id="${ref#app/}"; id="${id%%/*}"
            ;;
        runtime/*)
            id="${ref#runtime/}"; id="${id%%/*}"
            case "$id" in
                *.Debug)   id="${id%.Debug}" ;;
                *.Locale)  id="${id%.Locale}" ;;
                *.Sources) id="${id%.Sources}" ;;
                *) return 0 ;;
            esac
            ;;
        *) return 0 ;;
    esac
    printf '%s\n' "$id"
}

# True when the ref belongs to an app that is no longer in the registry.
ref_is_delisted() {
    local id
    id="$(ref_registry_id "$1")"
    [ -n "$id" ] && [ ! -f "$REGISTRY_DIR/$id/flatpark.yml" ]
}

app_record_path() {
    local app_id="$1"
    printf '%s/%s/flatpark.yml\n' "$REGISTRY_DIR" "$app_id"
}

load_app() {
    local app_id="${1:?load_app: app id required}"
    local record app_dir
    record="$(app_record_path "$app_id")"
    [ -f "$record" ] || die "missing app registry entry: $record"
    app_dir="$(dirname "$record")"

    if [ "${_FLATPARK_APP_OVERRIDE_STATE_READY:-0}" != "1" ]; then
        local override_var override_marker override_value
        local overridable_vars=(APP_SRC MANIFEST UPDATE_MODE APP_REF_URL APP_ICON APP_CATEGORY APP_TAGS APP_SOURCE_URL APP_WEBSITE)
        for override_var in "${overridable_vars[@]}"; do
            override_marker="_FLATPARK_${override_var}_HAS_OVERRIDE"
            override_value="_FLATPARK_${override_var}_OVERRIDE_VALUE"
            if declare -p "$override_var" >/dev/null 2>&1; then
                declare -g "$override_marker=1"
                declare -g "$override_value=${!override_var}"
            else
                declare -g "$override_marker=0"
                declare -g "$override_value="
            fi
        done
        declare -g "_FLATPARK_APP_OVERRIDE_STATE_READY=1"
    fi

    unset APP_ID APP_NAME APP_SUMMARY APP_BRANCH APP_SRC MANIFEST UPDATE_MODE APP_REF_URL \
        APP_ICON APP_CATEGORY APP_TAGS APP_SOURCE_URL APP_WEBSITE
    local override_var override_marker override_value has_override
    local overridable_vars=(APP_SRC MANIFEST UPDATE_MODE APP_REF_URL APP_ICON APP_CATEGORY APP_TAGS APP_SOURCE_URL APP_WEBSITE)
    for override_var in "${overridable_vars[@]}"; do
        override_marker="_FLATPARK_${override_var}_HAS_OVERRIDE"
        override_value="_FLATPARK_${override_var}_OVERRIDE_VALUE"
        has_override="${!override_marker:-0}"
        if [ "$has_override" = "1" ]; then
            declare -g "$override_var=${!override_value}"
        fi
    done

    need node
    local desc
    desc="$(node "$ROOT/scripts/read-descriptor.mjs" "$record")" \
        || die "failed to read descriptor: $record"
    local _FP_ID _FP_NAME _FP_SUMMARY _FP_BRANCH _FP_MANIFEST _FP_MODE \
          _FP_CATEGORY _FP_TAGS _FP_WEBSITE _FP_SOURCE_URL _FP_UPDATE_COMMAND
    # shellcheck disable=SC1090
    eval "$desc"

    APP_ID="$_FP_ID"
    APP_NAME="$_FP_NAME"
    APP_SUMMARY="$_FP_SUMMARY"
    [ "$APP_ID" = "$app_id" ] || die "registry id mismatch: wanted $app_id got $APP_ID"

    # Defaults compose the descriptor values; any explicit env override (captured
    # above) already won and is left untouched by these `:=` assignments.
    : "${APP_SRC:=$app_dir}"
    : "${MANIFEST:=$APP_SRC/$_FP_MANIFEST}"
    : "${APP_BRANCH:=${_FP_BRANCH:-stable}}"
    : "${UPDATE_MODE:=${_FP_MODE:-manual}}"
    : "${APP_CATEGORY:=${_FP_CATEGORY:-Apps}}"
    : "${APP_TAGS:=$_FP_TAGS}"
    : "${APP_WEBSITE:=$_FP_WEBSITE}"
    : "${APP_SOURCE_URL:=$_FP_SOURCE_URL}"
    : "${APP_REF_URL:=${REPO_URL%/}/$APP_ID.flatpakref}"
    : "${APP_ICON:=}"
    APP_UPDATE_COMMAND="$_FP_UPDATE_COMMAND"

    local var
    for var in APP_ID APP_NAME APP_SUMMARY APP_BRANCH APP_SRC MANIFEST APP_REF_URL UPDATE_MODE; do
        [ -n "${!var-}" ] || die "app registry entry $record did not set $var"
        declare -g "$var=${!var}"
    done
    for var in APP_CATEGORY APP_TAGS APP_ICON APP_SOURCE_URL APP_WEBSITE APP_UPDATE_COMMAND; do
        declare -g "$var=${!var}"
    done
    unset _FP_ID _FP_NAME _FP_SUMMARY _FP_BRANCH _FP_MANIFEST _FP_MODE \
          _FP_CATEGORY _FP_TAGS _FP_WEBSITE _FP_SOURCE_URL _FP_UPDATE_COMMAND
}
