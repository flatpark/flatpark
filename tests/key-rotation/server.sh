#!/bin/bash
# Server side of the key-rotation e2e: runs the REAL publish scripts
# (import-arch-repo.sh, publish-repo.sh) from the checkout mounted at /src, the
# way the publish job does, against a repo served over HTTP.
set -euo pipefail
export LC_ALL=C.UTF-8
export GNUPGHOME_DIR=/srv/gpg REPO_DIR=/srv/repo OUT_DIR=/srv/out
export GNUPGHOME=$GNUPGHOME_DIR
P=/srv/pub S=/src/scripts
fpr_of() { gpg --list-keys --with-colons "$1" | awk -F: '/^fpr:/{print $10; exit}'; }

# A build job's hand-over: the app (and on the first run the runtime) built
# into a throwaway repo signed with a throwaway key, like build-app.sh does.
handover() { # version
  local h=/srv/handover-$1 tg=/srv/throwaway-gpg d=/srv/src/app-$1
  rm -rf "$h" "$d"; ostree --repo="$h" init --mode=archive-z2
  if [ ! -d $tg ]; then mkdir -m700 $tg
    GNUPGHOME=$tg gpg -q --batch --passphrase '' --quick-generate-key "throwaway <t@x>" ed25519 sign never 2>/dev/null; fi
  local t; t=$(GNUPGHOME=$tg fpr_of throwaway)
  if [ "$1" = v1 ]; then
    local r=/srv/src/rt; mkdir -p $r/usr/share $r/files/share; echo rt > $r/files/share/marker; echo rt > $r/usr/share/marker
    printf '[Runtime]\nname=org.test.Platform\nruntime=org.test.Platform/x86_64/1\nsdk=org.test.Platform/x86_64/1\n' > $r/metadata
    flatpak build-export --runtime --gpg-sign=$t --gpg-homedir=$tg "$h" $r 1 >/dev/null
  fi
  mkdir -p "$d/files/bin"; printf '#!/bin/sh\necho %s\n' "$1" > "$d/files/bin/hello"; chmod +x "$d/files/bin/hello"
  printf '[Application]\nname=org.test.Hello\nruntime=org.test.Platform/x86_64/1\nsdk=org.test.Platform/x86_64/1\n' > "$d/metadata"
  flatpak build-finish --command=hello "$d" >/dev/null
  flatpak build-export --gpg-sign=$t --gpg-homedir=$tg "$h" "$d" stable >/dev/null
  "$S/import-arch-repo.sh" "$h" 2>&1 | sed 's/^/  /'
}

case "$1" in
init)
  mkdir -p -m700 "$GNUPGHOME"; mkdir -p "$P" /srv/src
  # "old" = stand-in for the live key: same shape as what CI holds (rsa4096
  # signing subkey, master stubbed). "new" = the real incoming CI subkey.
  T=$(mktemp -d); GNUPGHOME=$T gpg -q --batch --passphrase '' --quick-generate-key "OLD stand-in <sign@flatpark.org>" rsa4096 cert never
  of=$(GNUPGHOME=$T fpr_of OLD); GNUPGHOME=$T gpg -q --batch --passphrase '' --quick-add-key "$of" rsa4096 sign never
  GNUPGHOME=$T gpg --armor --export-secret-subkeys "$of" > /srv/old.secret.asc
  gpg -q --batch --import /srv/old.secret.asc
  gpg --export "$of" > $P/old.gpg
  T2=$(mktemp -d); GNUPGHOME=$T2 gpg -q --batch --import /keys/ci-subkey.secret.asc
  GNUPGHOME=$T2 gpg --export "$(GNUPGHOME=$T2 fpr_of 2026-11)" > $P/new.gpg
  cp /keys/ci-subkey.secret.asc /srv/new.secret.asc
  ostree --repo=$REPO_DIR init --mode=archive-z2
  handover v1
  "$S/publish-repo.sh" 2>&1 | tail -1 | sed 's/^/  /' ;;
backfill)  # rotation starts: CI gets the new subkey too; one dispatch with backfill_signatures
  gpg -q --batch --import /srv/new.secret.asc
  BACKFILL_SIGNATURES=1 "$S/publish-repo.sh" 2>&1 | grep -E "backfill|summary refreshed" | sed 's/^/  /' ;;
publish-v2)  # an ordinary publish during the overlap
  handover v2; "$S/publish-repo.sh" 2>&1 | tail -1 | sed 's/^/  /' ;;
switch)  # overlap ends: the old secret is deleted from the environment
  rm -rf "$GNUPGHOME"; mkdir -m700 "$GNUPGHOME"; gpg -q --batch --import /srv/new.secret.asc
  handover v3; "$S/publish-repo.sh" 2>&1 | tail -1 | sed 's/^/  /' ;;
inspect)
  # summary --view of this ostree does not list signatures: look for each
  # candidate key ID in the raw signature bytes instead.
  hex=$(od -An -tx1 -v $REPO_DIR/summary.sig | tr -d ' \n'); ids=""
  for f in $P/old.gpg $P/new.gpg; do
    kid=$(gpg --show-keys --with-colons $f | awk -F: '$1=="sub"||$1=="pub"{k=$5; c=$12} $1=="sub" && c~/s/{print k}' | tail -1)
    grep -qi "$kid" <<<"$hex" && ids="$ids$kid "
  done
  echo "  summary: $ids$(ostree --repo=$REPO_DIR summary --view 2>/dev/null | grep -q xa.gpg-keys && echo '+ xa.gpg-keys')"
  for ref in app/org.test.Hello/x86_64/stable runtime/org.test.Platform/x86_64/1; do
    c=$(ostree --repo=$REPO_DIR rev-parse $ref)
    echo "  $ref: $(ostree --repo=$REPO_DIR show $c 2>/dev/null | grep -oE 'key ID [0-9A-F]+' | awk '{print $3}' | tr '\n' ' ')"
  done ;;
serve) cd $REPO_DIR && exec python3 -m http.server 18765 --bind 127.0.0.1 >/srv/http.log 2>&1 ;;
esac
