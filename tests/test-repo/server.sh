#!/bin/bash
# Server side of the test-repo e2e: plays pr-checks (a build exported to a
# repo signed with a throwaway key, packed and zipped like an Actions
# artifact), GitHub (tests/lib/gh-stub.sh over /srv/gh), Flathub (a stand-in
# runtime remote) and the bucket (rclone's local backend at /srv/bucket,
# served over HTTP), and runs the REAL scripts/test-repo-*.sh from /src.
set -euo pipefail
export LC_ALL=C.UTF-8
PR=7 APP=org.flatpark.TestApp EVIL=org.evil.App RT=org.test.Platform
WWW=http://127.0.0.1:18766 BUCKET_URL=http://127.0.0.1:18767
HEAD_SHA=1111111111111111111111111111111111111111
G=/srv/gh/repos/o/r

# What the real scripts see.
export GITHUB_REPOSITORY=o/r GH_FX=/srv/gh PATH=/srv/bin:$PATH
export RCLONE_CONFIG_R2_TYPE=local TEST_REPO_BUCKET=/srv/bucket TEST_REPO_BASE_URL=$BUCKET_URL/
export TEST_REPO_PUBKEY=/srv/keys/testing.pub.asc RUNTIME_REPO_URL=$WWW/flathub/flathub.flatpakrepo

newkey() { # <homedir> <uid> <algo> <usage>
  mkdir -p "$1"; chmod 700 "$1"
  GNUPGHOME=$1 gpg -q --batch --passphrase '' --quick-generate-key "$2" "$3" "$4" never 2>/dev/null
  GNUPGHOME=$1 gpg --list-keys --with-colons 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}'
}
testing_key() { FLATPAK_TESTING_GPG_KEY=$(cat /srv/keys/testing.secret.asc); export FLATPAK_TESTING_GPG_KEY; }
pr_json() { # <state> <merged> <labels-json>
  jq -n --arg s "$1" --argjson m "$2" --argjson l "$3" --arg h $HEAD_SHA \
    '{number: 7, state: $s, merged: $m, labels: $l, head: {sha: $h}}' > $G/pulls/$PR.json
}

case "$1" in
init)
  mkdir -p /srv/bin /srv/keys /srv/www/flathub /srv/build /srv/handover $G/pulls/$PR $G/actions/workflows/pr-checks.yml \
           $G/actions/runs/77 $G/actions/artifacts/101 /srv/bucket
  ln -sf /src/tests/lib/gh-stub.sh /srv/bin/gh
  # The testing key has the production one's shape: one rsa4096 [SC] key.
  T=/srv/keys/testing-home; tfpr=$(newkey $T "FlatPark Testing (e2e) <testing@example.org>" rsa4096 sign,cert)
  GNUPGHOME=$T gpg --armor --export "$tfpr" > /srv/keys/testing.pub.asc
  GNUPGHOME=$T gpg --armor --export-secret-keys "$tfpr" > /srv/keys/testing.secret.asc
  F=/srv/keys/flathub-home; ffpr=$(newkey $F "Flathub stand-in <f@example.org>" ed25519 sign)
  W=/srv/keys/throwaway-home; wfpr=$(newkey $W "pr-checks throwaway <t@example.org>" ed25519 sign)

  # Flathub stand-in: the runtime, a static busybox as its /usr/bin.
  r=/srv/build/runtime; mkdir -p $r/usr/bin $r/files
  cp /bin/busybox $r/usr/bin/; for a in sh cat tr rm; do ln -s busybox $r/usr/bin/$a; done
  printf '[Runtime]\nname=%s\nruntime=%s/x86_64/1\nsdk=%s/x86_64/1\n' $RT $RT $RT > $r/metadata
  ostree --repo=/srv/www/flathub/repo init --mode=archive-z2
  flatpak build-export --runtime --gpg-sign="$ffpr" --gpg-homedir=$F /srv/www/flathub/repo $r 1 >/dev/null
  flatpak build-update-repo --gpg-sign="$ffpr" --gpg-homedir=$F /srv/www/flathub/repo >/dev/null
  printf '[Flatpak Repo]\nTitle=Flathub stand-in\nUrl=%s/flathub/repo/\nGPGKey=%s\n' \
    $WWW "$(GNUPGHOME=$F gpg --export "$ffpr" | base64 -w0)" > /srv/www/flathub/flathub.flatpakrepo

  # The extra-data payload, fetched by the client from "upstream" on install.
  echo hello-extra-data > /srv/www/payload.txt
  sha=$(sha256sum /srv/www/payload.txt | cut -d' ' -f1); size=$(stat -c %s /srv/www/payload.txt)

  # pr-checks: the PR's app (extra-data, unpacked by apply_extra), plus what
  # must never be published for this PR: another PR's app and a dependency.
  h=/srv/handover/repo; ostree --repo=$h init --mode=archive-z2
  flatpak build-export --runtime --gpg-sign="$wfpr" --gpg-homedir=$W $h $r 1 >/dev/null
  for id in $APP $EVIL; do
    d=/srv/build/$id; mkdir -p "$d/files/bin"
    printf '#!/bin/sh\necho %s\n' "$id" > "$d/files/bin/hello"
    printf '#!/bin/sh\ntr a-z A-Z < payload.txt > applied.txt && rm payload.txt\n' > "$d/files/bin/apply_extra"
    chmod +x "$d"/files/bin/*
    printf '[Application]\nname=%s\nruntime=%s/x86_64/1\nsdk=%s/x86_64/1\n' "$id" $RT $RT > "$d/metadata"
    flatpak build-finish --command=hello --extra-data="payload.txt:$sha:$size:$size:$WWW/payload.txt" "$d" >/dev/null
    # A fixed, old build time: the e2e checks the EOL commit keeps it.
    flatpak build-export --timestamp=2026-01-02T03:04:05Z --gpg-sign="$wfpr" --gpg-homedir=$W $h "$d" stable >/dev/null
  done
  echo "  artifact refs: $(ostree --repo=$h refs | tr '\n' ' ')"
  tar -C /srv/handover -cf /srv/handover/flatpak-repo-x86_64.tar repo
  python3 -I -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z: z.write(sys.argv[2], "flatpak-repo-x86_64.tar")' \
    $G/actions/artifacts/101/zip /srv/handover/flatpak-repo-x86_64.tar

  # GitHub: PR 7 is open, labeled, touches only registry/$APP/, and pr-checks
  # run 77 passed on its head and uploaded the artifact above.
  pr_json open false '[{"name":"needs-testers"}]'
  echo "[{\"filename\":\"registry/$APP/flatpark.yml\"},{\"filename\":\"docs/x.md\"}]" > $G/pulls/$PR/files.json
  echo "[{\"number\":$PR,\"labels\":[{\"name\":\"needs-testers\"}]}]" > $G/pulls.json
  jq -n --arg h $HEAD_SHA '{workflow_runs: [{id: 77, head_sha: $h, event: "pull_request", status: "completed", conclusion: "success", created_at: "2026-11-16T00:00:00Z"}]}' \
    > $G/actions/workflows/pr-checks.yml/runs.json
  echo '{"artifacts":[{"id":101,"name":"flatpak-repo-x86_64-pr7","expired":false}]}' > $G/actions/runs/77/artifacts.json ;;
plan)        /src/scripts/test-repo-plan.sh sweep ;;
plan-run)    /src/scripts/test-repo-plan.sh run 77 $HEAD_SHA ;;
reconcile)   testing_key; /src/scripts/test-repo-reconcile.sh $PR ;;
decide)      /src/scripts/test-repo-reconcile.sh --decide $PR ;;
expire)      jq '.artifacts[].expired = ($v == "1")' --arg v "$2" $G/actions/runs/77/artifacts.json > /tmp/a.json \
               && mv /tmp/a.json $G/actions/runs/77/artifacts.json ;;
calls)       cat /srv/gh/calls ;;
merge)       pr_json closed true '[{"name":"needs-testers"}]'; echo '[]' > $G/pulls.json ;;
unlabel)     pr_json open false '[]'; echo "[{\"number\":$PR,\"labels\":[]}]" > $G/pulls.json ;;
relabel)     pr_json open false '[{"name":"needs-testers"}]'; echo "[{\"number\":$PR,\"labels\":[{\"name\":\"needs-testers\"}]}]" > $G/pulls.json ;;
age-marker)  date -u -d "$2 days ago" +%Y-%m-%dT%H:%M:%SZ > /srv/bucket/pr/$PR/retired ;;
show)        # <what>
  case "$2" in
    # Not `ostree refs`: opening the repo would add a tmp/ to the bucket dir.
    refs)    (cd /srv/bucket/pr/$PR/refs/heads && find . -type f | sed 's#^\./##' | sort | tr '\n' ' ') ;;
    files)   find /srv/bucket/pr/$PR -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ' ;;
    comment) jq -r '.[0].body' $G/issues/$PR/comments.json ;;
    gone)    [ ! -e /srv/bucket/pr/$PR ] && echo gone ;;
    # "<checksum> <timestamp>" of the app's served commit, read from a copy
    # (opening the bucket dir itself would add a tmp/ to it).
    commit)  rm -rf /tmp/peek; cp -r /srv/bucket/pr/$PR /tmp/peek
             c=$(ostree --repo=/tmp/peek rev-parse app/$APP/x86_64/stable)
             echo "$c $(ostree --repo=/tmp/peek show "$c" | sed -n 's/^Date: *//p')" ;;
  esac ;;
serve)
  (cd /srv/www && exec python3 -m http.server 18766 --bind 127.0.0.1 >/srv/www.log 2>&1) &
  cd /srv/bucket && exec python3 -m http.server 18767 --bind 127.0.0.1 >/srv/bucket.log 2>&1 ;;
esac
