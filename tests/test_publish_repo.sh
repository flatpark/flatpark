#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v ostree >/dev/null || { echo "test_publish_repo: SKIP (no ostree)"; exit 0; }
command -v flatpak >/dev/null || { echo "test_publish_repo: SKIP (no flatpak)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
env_common=(OUT_DIR="$tmp/out" GNUPGHOME_DIR="$tmp/gnupg")

env "${env_common[@]}" "$ROOT/scripts/gen-signing-key.sh" >/dev/null

repo="$tmp/repo"
ostree --repo="$repo" init --mode=archive-z2
mkdir -p "$tmp/tree/files"; echo hi > "$tmp/tree/files/x"
ostree --repo="$repo" commit --branch=app/test.App/x86_64/stable --subject=t "$tmp/tree" >/dev/null

env "${env_common[@]}" "$ROOT/scripts/publish-repo.sh" "$repo"
assert_file "$repo/summary"
assert_file "$repo/summary.sig"

# The summary advertises the signing key (xa.gpg-keys): how clients learn a new
# key during a rotation.
ostree --repo="$repo" summary --view | grep -q "xa.gpg-keys" \
    || { echo "FAIL: summary does not advertise xa.gpg-keys"; exit 1; }

# --- key rotation: a second signing key in the keyring ----------------------
commit="$(ostree --repo="$repo" rev-parse app/test.App/x86_64/stable)"
sigs() { ostree --repo="$repo" show "$commit" | grep -oE 'key ID [0-9A-F]+' | sort -u | wc -l; }
nsig() { ostree --repo="$repo" show "$commit" | grep -c 'key ID'; }
ostree --repo="$repo" gpg-sign --gpg-homedir="$tmp/gnupg" "$commit" \
    "$(GNUPGHOME="$tmp/gnupg" gpg --list-keys --with-colons | awk -F: '/^fpr:/{print $10; exit}')"
assert_eq "$(nsig)" 1
GNUPGHOME="$tmp/gnupg" gpg -q --batch --passphrase '' \
    --quick-generate-key "Incoming <sign@flatpark.org>" ed25519 sign never 2>/dev/null

# Without BACKFILL_SIGNATURES an existing commit is left alone...
env "${env_common[@]}" "$ROOT/scripts/publish-repo.sh" "$repo" 2>/dev/null
assert_eq "$(nsig)" 1
# ...but the summary is signed with both keys...
# (Counted from the raw bytes: every OpenPGP signature names its issuer key ID,
# and older ostree's `summary --view` does not list the signatures.)
sig_hex="$(od -An -tx1 -v "$repo/summary.sig" | tr -d ' \n')"
n=0
while read -r _ kid; do
    grep -qi "$kid" <<<"$sig_hex" && n=$((n + 1))
done < <(GNUPGHOME="$tmp/gnupg" bash -c '. "$1/scripts/lib/common.sh"; signing_keys' _ "$ROOT")
assert_eq "$n" 2
# ...and what it advertises (and the discovery files carry) holds both keys.
n="$(GNUPGHOME="$tmp/gnupg" GNUPGHOME_DIR="$tmp/gnupg" bash -c '
    . "$1/scripts/lib/common.sh"; export_signing_pubkeys "$2/pub.gpg"
    gpg --show-keys --with-colons "$2/pub.gpg" | grep -c "^pub:"' _ "$ROOT" "$tmp")"
assert_eq "$n" 2

# Backfill adds the missing signature exactly once, and is idempotent.
BACKFILL_SIGNATURES=1 env "${env_common[@]}" "$ROOT/scripts/publish-repo.sh" "$repo" 2>/dev/null
assert_eq "$(nsig)" 2
assert_eq "$(sigs)" 2
BACKFILL_SIGNATURES=1 env "${env_common[@]}" "$ROOT/scripts/publish-repo.sh" "$repo" 2>/dev/null
assert_eq "$(nsig)" 2

# Keys shaped differently from ours still yield one signature each, recorded
# under the ID gpg really signs with, so the backfill stays idempotent: a
# primary that can sign and has a signing subkey (gpg signs with the subkey),
# and a primary with two signing subkeys.
G="$tmp/gnupg"
gk() { GNUPGHOME="$G" gpg -q --batch --passphrase '' "$@" 2>/dev/null; }
gk --quick-generate-key "Both <sign@flatpark.org>" ed25519 sign,cert never
both="$(GNUPGHOME="$G" gpg --list-keys --with-colons Both | awk -F: '/^fpr:/{print $10; exit}')"
gk --quick-add-key "$both" ed25519 sign never
gk --quick-generate-key "Two <sign@flatpark.org>" ed25519 cert never
two="$(GNUPGHOME="$G" gpg --list-keys --with-colons Two | awk -F: '/^fpr:/{print $10; exit}')"
gk --quick-add-key "$two" ed25519 sign never
gk --quick-add-key "$two" ed25519 sign never
BACKFILL_SIGNATURES=1 env "${env_common[@]}" "$ROOT/scripts/publish-repo.sh" "$repo" 2>/dev/null
assert_eq "$(nsig)" 4
assert_eq "$(sigs)" 4
BACKFILL_SIGNATURES=1 env "${env_common[@]}" "$ROOT/scripts/publish-repo.sh" "$repo" 2>/dev/null
assert_eq "$(nsig)" 4
echo "test_publish_repo: PASS"
