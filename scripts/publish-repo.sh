#!/usr/bin/env bash
# Regenerate and sign the summary of the repo (REPO_DIR by default).
#
# Signed with every signing key in GNUPGHOME_DIR (signing_args), and the
# summary advertises their public keys in xa.gpg-keys: on its next update or
# install, a client verifies the summary with a key it already trusts and then
# adds the advertised keys to that remote's keyring. That is how a new key
# reaches existing users during a rotation (docs/reference/signing-key-rotation.md).
# Clients only ever add keys this way, never drop one.
#
# BACKFILL_SIGNATURES=1 additionally signs the current commit of every app/ and
# runtime/ ref with each signing key whose signature it lacks. New commits are
# signed with all keys when they are built or imported; backfilling covers the
# ones nothing rebuilt since a key was added, so a client that trusts only the
# new key can still install them. It runs once per rotation, not every publish:
# it costs ~0.1 s per ref, and `ostree gpg-sign` does not deduplicate (signing
# twice with one key stores two signatures), so each commit's existing
# signature key IDs are checked first.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need flatpak; need gpg; need ostree
export GNUPGHOME="$GNUPGHOME_DIR"
repo="${1:-$REPO_DIR}"
[ -d "$repo" ] || die "repo dir not found: $repo"
signing_args sign
mapfile -t keys < <(signing_keys)

if [ "${BACKFILL_SIGNATURES:-}" = 1 ]; then
    signed=0 total=0
    while read -r ref; do
        commit="$(ostree --repo="$repo" rev-parse "$ref")"
        have="$(ostree --repo="$repo" show "$commit" 2>/dev/null | grep -oE 'key ID [0-9A-F]+' | awk '{print $3}' || true)"
        missing=()
        for k in "${keys[@]}"; do
            fpr="${k% *}" kid="${k#* }"
            grep -qxF "$kid" <<<"$have" || missing+=("$fpr")
        done
        total=$((total + 1))
        [ "${#missing[@]}" -gt 0 ] || continue
        ostree --repo="$repo" gpg-sign --gpg-homedir="$GNUPGHOME_DIR" "$commit" "${missing[@]}"
        signed=$((signed + 1))
    done < <(ostree --repo="$repo" refs | grep -E '^(app|runtime)/')
    log "backfill: added signatures to $signed of $total commits"
fi

pubkeys="$(mktemp)"; trap 'rm -f "$pubkeys"' EXIT
export_signing_pubkeys "$pubkeys"
flatpak build-update-repo "${sign[@]}" --gpg-import="$pubkeys" "$repo"
[ -f "$repo/summary.sig" ] || die "summary.sig not produced"
log "summary refreshed and signed in $repo (${#keys[@]} key(s))"
