#!/usr/bin/env bash
# Import the app refs another machine built into the authoritative repo, signed
# with the FlatPark key.
#
# Every arch is built in its own CI job on a native runner, and none of them
# gets the signing key: each builds into its own repo signed with a throwaway
# key and hands that repo over. Here every app/ and runtime/ ref in it is
# re-committed into REPO_DIR with `flatpak build-commit-from` — the same step
# flat-manager uses to publish Flathub's builds. It copies the tree (whose
# `metadata` file carries the extra-data pins) and the commit metadata, parents
# the new commit on the ref's current one, and signs it with our key; the
# throwaway signature is never looked at. A tree identical to the published one
# is skipped ("no change"), so a rebuild that changed nothing pushes no update.
# The summary is left alone: publish-repo.sh regenerates and signs it once
# everything is in.
#
# Usage: import-arch-repo.sh <src-repo>
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need flatpak; need ostree; need gpg
export GNUPGHOME="$GNUPGHOME_DIR"
src="${1:?usage: import-arch-repo.sh <src-repo>}"
[ -d "$src/objects" ] || die "not an ostree repo: $src"
[ -d "$REPO_DIR/objects" ] || die "repo dir not found: $REPO_DIR"
fpr="$(gpg --list-keys --with-colons "$KEY_EMAIL" | awk -F: '/^fpr:/{print $10; exit}')"
[ -n "$fpr" ] || die "no signing key (run gen-signing-key.sh)"

# appstream/* and ostree-metadata are per-repo indexes, rebuilt by
# build-update-repo from the refs; importing the source repo's would clobber them.
mapfile -t refs < <(ostree --repo="$src" refs | grep -E '^(app|runtime)/' | sort)
[ "${#refs[@]}" -gt 0 ] || die "no app or runtime refs in $src"
for ref in "${refs[@]}"; do
    flatpak build-commit-from --src-repo="$src" --no-update-summary \
        --gpg-sign="$fpr" --gpg-homedir="$GNUPGHOME_DIR" "$REPO_DIR" "$ref"
    log "imported $ref"
done
