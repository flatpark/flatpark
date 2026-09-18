#!/usr/bin/env bash
# Run an app's apply_extra.sh the way a *system-wide* install runs it: as root,
# with every capability dropped, offline, against the real pinned artifact.
#
# Why this exists. `flatpak install` (system) executes apply_extra under
# flatpak-system-helper as root with `--cap-drop ALL`, so the script cannot
# chown to whatever uid the upstream archive happens to record. bsdtar and tar
# both restore ownership by default under uid 0; the resulting EPERM is fatal
# under `set -e` even though every member extracted correctly, and the user sees
# only `apply_extra script failed, exit status 256` (512 for GNU tar) with the
# real message buried in the system helper's journal.
#
# Nothing else in CI reaches this code path: build-app.sh only *builds*, and
# extra-data is fetched at install time, so a green build says nothing about
# whether the app can actually be installed system-wide. A `--user` install
# won't catch it either — there the script runs as the invoking user and
# ownership is never restored.
#
# Getting "uid 0 with no capabilities" has two routes, and we pick whichever the
# host allows:
#
#   * Real root (`sudo bwrap ... --cap-drop ALL`). This is what flatpak actually
#     does, so a chown fails with the same EPERM the system helper reports. Used
#     when already root, or when passwordless sudo is available (CI).
#   * An unprivileged user namespace (`bwrap --unshare-user --uid 0`), whose root
#     has no capabilities over the host. A chown to an unmapped uid fails with
#     EINVAL rather than EPERM — a different errno, but the same failure branch
#     in both libarchive and tar. Used on a dev box without sudo.
#
# The userns route is not always available: distros that set
# `kernel.apparmor_restrict_unprivileged_userns=1` (Ubuntu 23.10+, and the
# GitHub Actions runners) deny it, and bwrap fails while *setting up* the
# sandbox — before apply_extra runs at all. That is why the routes are probed
# rather than assumed, and why a probe failure is reported as its own error
# instead of being blamed on the unpack script.
#
# Usage: check-apply-extra.sh <app-id>...
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need flatpak; need bwrap; need curl; need sha256sum; need node

[ "$#" -gt 0 ] || die "usage: check-apply-extra.sh <app-id>..."

arch="$(flatpak --default-arch)"

# Mirror flatpak's apply_extra sandbox: uid 0, no caps, no network, no /proc
# (flatpak passes FLATPAK_RUN_FLAG_NO_PROC there).
sandbox_common=(--unshare-pid --unshare-net --die-with-parent --cap-drop ALL)

# Pick a route to uid 0, most faithful first, and prove it works before trusting
# a nonzero exit from apply_extra to mean anything.
sandbox_cmd=()
probe_sandbox() {
    "${sandbox_cmd[@]}" "${sandbox_common[@]}" --ro-bind /usr /usr \
        --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib64 /lib64 \
        /bin/true 2>/dev/null
}
sandbox_ok=""
as_root=()       # how to run a command as real root, empty if we already are
real_root=""     # set when uid 0 in the sandbox is the host's real root
if [ "$(id -u)" = 0 ]; then
    sandbox_cmd=(bwrap)
    real_root=1
    probe_sandbox || die "bwrap cannot create a sandbox even as root"
else
    if sudo -n true 2>/dev/null; then
        sandbox_cmd=(sudo -n bwrap)
        if probe_sandbox; then sandbox_ok=1; as_root=(sudo -n); real_root=1; fi
    fi
    if [ -z "$sandbox_ok" ]; then
        # No sudo, or sudo's bwrap failed: fall back to an unprivileged userns.
        sandbox_cmd=(bwrap --unshare-user --uid 0 --gid 0)
        probe_sandbox || die "cannot create the apply_extra sandbox: unprivileged user namespaces look restricted (check kernel.apparmor_restrict_unprivileged_userns) and no passwordless sudo is available. Run this as root, grant passwordless sudo, or relax that sysctl."
    fi
fi
# Root-owned files land in the work dir on the real-root route; clean up with the
# same privilege that made them.
cleanup() { rm -rf "$@" 2>/dev/null || "${as_root[@]}" rm -rf "$@" 2>/dev/null || true; }

check_one() {
    load_app "$1"
    local apply="$APP_SRC/apply_extra.sh"
    if [ ! -f "$apply" ]; then
        log "$APP_ID: no apply_extra.sh, nothing to check"
        return 0
    fi

    local runtime="" runtime_version="" sources=() kind a b c d
    while IFS=$'\t' read -r kind a b c d; do
        case "$kind" in
            runtime) runtime="$a"; runtime_version="$b" ;;
            extra)   sources+=("$a"$'\t'"$b"$'\t'"$c"$'\t'"$d") ;;
        esac
    done < <(node "$ROOT/scripts/read-extra-data.mjs" "$MANIFEST" "$arch")

    if [ "${#sources[@]}" -eq 0 ]; then
        log "$APP_ID: no extra-data for $arch, nothing to check"
        return 0
    fi

    # apply_extra runs against the runtime's /usr, so the runtime must be present.
    # A dev box already has it from building the app; INSTALL_RUNTIME=1 lets a
    # workflow that only checks payloads (update-check.yml) fetch it instead of
    # having to build anything first, from $RUNTIME_REMOTE (default flathub).
    local loc files
    loc="$(flatpak info --show-location "$runtime//$runtime_version" 2>/dev/null)" || loc=""
    if [ -z "$loc" ] && [ -n "${INSTALL_RUNTIME:-}" ]; then
        log "$APP_ID: installing runtime $runtime//$runtime_version"
        flatpak install --user -y --noninteractive "${RUNTIME_REMOTE:-flathub}" \
            "runtime/$runtime/$arch/$runtime_version" \
            || die "$APP_ID: cannot install runtime: $runtime//$runtime_version"
        loc="$(flatpak info --show-location "$runtime//$runtime_version" 2>/dev/null)" || loc=""
    fi
    [ -n "$loc" ] || die "$APP_ID: runtime not installed: $runtime//$runtime_version (set INSTALL_RUNTIME=1 to fetch it)"
    files="$loc/files"
    [ -d "$files" ] || die "$APP_ID: runtime has no files dir: $files"

    # check_one always runs in a subshell, so an EXIT trap is scoped to this app
    # and still fires on the `die` paths below. The log lives outside $work:
    # apply_extra deletes the extra-data it consumed, and would take the log too.
    local work log_file
    work="$(mktemp -d)"
    log_file="$(mktemp)"
    # shellcheck disable=SC2064
    trap "cleanup '$work' '$log_file'" EXIT

    # Both pins are checked, and `size` is not redundant with `sha256`: flatpak
    # compares the declared size against the Content-Length *before* it reads a
    # byte, so a stale size aborts the install with "Wrong size for extra data"
    # and the checksum never gets a chance to disagree. Nothing else in CI
    # catches it — extra-data is not fetched at build time, so a green build and
    # a green apply_extra run say nothing about it. Re-pinning a URL without its
    # size shipped exactly that breakage once.
    local src filename url want want_size got got_size
    for src in "${sources[@]}"; do
        IFS=$'\t' read -r filename url want want_size <<<"$src"
        log "$APP_ID: fetching $filename"
        curl -fsSL --retry 3 --max-time 900 -o "$work/$filename" "$url" \
            || die "$APP_ID: download failed: $url"
        got="$(sha256sum "$work/$filename" | cut -d' ' -f1)"
        [ "$got" = "$want" ] || die "$APP_ID: sha256 mismatch for $filename (pinned $want, got $got)"
        got_size="$(stat -c%s "$work/$filename")"
        [ "$got_size" = "$want_size" ] \
            || die "$APP_ID: size mismatch for $filename (pinned $want_size, got $got_size) — flatpak rejects this at install time with 'Wrong size for extra data'"
    done

    cp "$apply" "$work/apply_extra.sh"

    # A system-wide install unpacks into a root-owned /app/extra. On the real-root
    # route the sandbox has uid 0 but no CAP_DAC_OVERRIDE, so a work dir still
    # owned by the invoking user is neither traversable nor writable there —
    # match production and hand it to root. The userns route needs no such thing:
    # its uid 0 *is* the invoking user.
    if [ -n "$real_root" ]; then
        "${as_root[@]}" chown -R 0:0 "$work"
    fi

    # The runtime goes at /usr, the extra-data dir is bound read-write at
    # /app/extra. sandbox_cmd/sandbox_common carry the uid-0-no-caps setup.
    local rc=0
    "${sandbox_cmd[@]}" "${sandbox_common[@]}" \
        --ro-bind "$files" /usr \
        --symlink usr/bin /bin --symlink usr/sbin /sbin \
        --symlink usr/lib /lib --symlink usr/lib64 /lib64 \
        --bind "$work" /app/extra --chdir /app/extra \
        --dev /dev --tmpfs /tmp \
        /bin/sh -c 'sh /app/extra/apply_extra.sh' >"$log_file" 2>&1 || rc=$?

    if [ "$rc" -ne 0 ]; then
        # bwrap reports its own setup failures on stderr prefixed `bwrap:`, and
        # exits before apply_extra runs. Blaming the unpack script for those sent
        # one reviewer chasing a --no-same-owner bug that wasn't there.
        if grep -q '^bwrap: ' "$log_file"; then
            warn "$APP_ID: bwrap output:"
            tail -n 20 "$log_file" | sed 's/^/    /' >&2
            die "$APP_ID: the sandbox failed to start, so apply_extra never ran. This is a problem with this checker's environment, not with the app."
        fi
        # A chown failure names every member; the tail is enough to identify it.
        warn "$APP_ID: last lines of apply_extra output:"
        tail -n 20 "$log_file" | sed 's/^/    /' >&2
        die "$APP_ID: apply_extra failed under a system-wide install (exit $rc; flatpak would report 'exit status $((rc * 256))'). If it unpacks an archive, it must do so with --no-same-owner."
    fi
    log "$APP_ID: apply_extra OK as root with no capabilities"
}

# Each app in its own subshell so load_app's globals and the tmpdir trap don't
# leak between them — and so one failure still reports the rest.
fail=0
for id in "$@"; do
    ( check_one "$id" ) || fail=1
done
exit "$fail"
