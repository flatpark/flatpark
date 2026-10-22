---
description: Build the package, test it locally, and open the pull request.
order: 7
---

# Submitting an app

Anyone can add an app: write the package, build it, use the app from the build,
and open a pull request. Before you start, check the app
[can be packaged](can-it-be-packaged.md); then write the files described in
[what a package is](basics.md) for the download you picked
([choosing a format](formats/README.md)).

1. **Build** the package locally.
2. **Install it and use it.** Launch the app and try its main feature. A
   package that only builds is not tested, and a PR without this is not
   reviewed.
3. **Open the PR**, saying what you tested and what you couldn't.

CI then checks the descriptor, builds the app (forks included, once a
maintainer approves the run), and a reviewer goes through the
[review runbook](../reviewers/review-runbook.md). On merge, the app is published.

## Build

Use the Flathub build of `flatpak-builder`. It carries a fixed SDK toolchain
(`bsdunzip`, `appstreamcli`, `node`), so the result doesn't depend on your
distribution:

```sh
flatpak install flathub org.flatpak.Builder
node scripts/read-descriptor.mjs registry/com.example.App/flatpark.yml
node scripts/audit-descriptor.mjs registry/com.example.App/flatpark.yml
./scripts/check-apply-extra.sh com.example.App
./scripts/publish.sh --verify com.example.App
```

`publish.sh --verify` builds the app, installs it from a temporary local remote
to prove the repo is installable, then removes both.
`check-apply-extra.sh` unpacks the real download the way a system-wide install
does, which a `--user` install never shows. Both must pass.

## Test

Before the first run, look at `~/.var/app/com.example.App`. Packages often
keep the app id that Flathub or upstream use, so that folder can hold the
user's real profile from an earlier install. If it exists, ask before touching
it, or move it to a backup name and move it back after the test; for a browser,
point the test at its own profile directory instead. Never delete it to get a
clean first start: one test run did that and destroyed a user's browser profile.

Keep the build installed and use it:

```sh
ls ~/.var/app/com.example.App      # exists already? see above
FLATPARK_VERIFY_KEEP=1 ./scripts/publish.sh --verify com.example.App
flatpak --user run com.example.App
# … use the app's main feature, quit, start it again: are settings still there?
flatpak kill com.example.App
flatpak --user uninstall -y com.example.App
flatpak --user remote-delete --force flatpark-local
rm -rf ~/.var/app/com.example.App  # only if it didn't exist before the test
```

Check at least:

- the app starts and its window looks right;
- its main feature works;
- settings and data survive a restart;
- nothing new appears in your home directory that shouldn't.

## Open the PR

- **Branch:** `add/<app-id>` for a new app, `fix/<slug>` for a change.
- **Commit subject:** [Conventional Commits](https://www.conventionalcommits.org/),
  `feat(<short-name>): add <App>, <what it is> (<app-id>)` for a new app,
  `fix(<short-name>): <what changed>` for a fix. The body says why, not which
  files.
- **PR title:** the commit subject.
- **PR body:**
  - **What:** the app and its id.
  - **Packaging:** the download used, the runtime, anything around the vendor's
    build (wrapper settings, prebuilt stacks, extra downloads).
  - **Sandbox:** the permissions granted and why; the ones left out, with the
    `flatpak override` lines in the metainfo that turn them on.
  - **Tested:** what you did with the app, and what you couldn't (an account,
    hardware, a desktop you don't run).
  - **Flathub:** if the app is on Flathub, why it should be here too
    ([rules](can-it-be-packaged.md#apps-already-on-flathub)).

If you are the app's developer, say so in the PR; it is how the developer-approved
shield gets added ([upstream approvals](../reference/upstream-approvals.md)).

## For agents

### Working beside other sessions

Another session may be working in the same checkout: one `git checkout` there
moves the branch from under you, and `git add -u` sweeps their half-done files
into your commit.

- Do anything that spans more than one command in your own
  `git worktree add`, under `$HOME` (the sandboxed builder can't see `/tmp`).
- Before every commit, read `git status --short` and unstage anything that
  isn't yours; never `git add -u` blindly. Take a message from an explicit sha,
  not `HEAD`.
- To squash WIP commits, `git reset --soft $(git merge-base HEAD origin/main)`
  and then rebase. `reset --soft origin/main` after `main` has moved stages a
  revert of everything merged meanwhile. A `D` or `M` outside your app's
  directory means stop.
- If something goes wrong, look at `git reflog` before any reset or checkout;
  the work is almost always still in a detached commit.

### Building without the Flathub builder

A host `flatpak-builder` is used in preference if installed; that is what CI
does, because the sandboxed builder needs a session bus to reach the host's
Flatpak and a headless runner has none. The sandboxed builder has its own
`/tmp`, so a `REPO_DIR`, `OUT_DIR` or `GNUPGHOME_DIR` you set yourself has to be
under `$HOME` or the repo; the scripts stop with an explanation if it isn't.
A host `flatpak-builder` needs `bsdunzip` (package `libarchive-tools`) to unpack
a zip source; without it the build fails on the zip, not on your manifest.

### Keeping test installs apart

`publish.sh --verify` adds a remote named `flatpark-local` to your `--user`
installation and never touches your real `flatpark` remote (it refuses to run if
the names collide). If the app was already installed from another remote, it is
moved aside with `--reinstall` and restored afterwards. The scratch repo is
rebuilt on every run, so don't leave `flatpark-local` around between sessions.

For longer testing, use a separate installation:

```sh
# once: an installation named "test"
sudo install -d /etc/flatpak/installations.d
printf '[Installation "test"]\nPath=%s/.local/share/flatpak-test\nDisplayName=FlatPark test\n' \
  "$HOME" | sudo tee /etc/flatpak/installations.d/test.conf >/dev/null

flatpak --installation=test remote-add --no-gpg-verify flatpark "file://$PWD/out/repo"
flatpak --installation=test install flatpark com.example.App
flatpak --installation=test uninstall --all
```

Without root, use your `--user` installation with a remote name of its own:

```sh
flatpak --user remote-add --if-not-exists --no-gpg-verify test-tmp "file://$PWD/out/repo"
flatpak --user install -y test-tmp com.example.App
# … test …
flatpak kill com.example.App
flatpak --user uninstall -y com.example.App
flatpak --user remote-delete test-tmp
rm -rf ~/.var/app/com.example.App  # only if it didn't exist before the test
```

**Don't use `FLATPAK_USER_DIR` for isolation.** That installation isn't
registered in `/etc/flatpak/installations.d`, so the host's Flatpak portal
doesn't know it exists, and anything relying on `flatpak-spawn` fails. That
includes glycin, the image loader of the GNOME 48+ runtimes, so the app aborts
at start with `Failed to load .../image-missing.png: Loader process exited
early` — which looks exactly like the package crashing, and isn't.

`flatpak install --reinstall` from a local `file://` remote can keep the old
commit; uninstall and install again after a rebuild. `timeout flatpak run`
stops only the client, so run `flatpak kill <id>` after every test.

### Checks CI runs

- `pr-checks`: validates the descriptor, runs `audit-descriptor.mjs` and the
  test suite, checks links, runs `check-apply-extra.sh` when a pin changed, and
  builds the changed app. A fork's build runs without secrets, signed with a
  throwaway key.
- `audit-descriptor.mjs` fails a package whose scripts inject code, run host
  commands or turn off an inner sandbox without declaring it, and a package
  without `<id>.png` or `<id>.svg`.

### What review checks

The [review runbook](../reviewers/review-runbook.md) is the full list. The
common reasons a PR is sent back:

- **Not run.** The PR doesn't say what was tested and what wasn't.
- **Optional permissions granted by default** instead of documented as
  overrides; see [permissions](permissions.md).
- **The wrong kind of source.** The app and anything it needs come in as
  `extra-data`, with `sha256` and `size`. An `archive` source is only for a
  prebuilt stack the catalog already consumes that way. `git` sources aren't
  accepted.
- **Download not from the official channel:** the vendor's domain or the real
  upstream repository, never a personal account or mirror.
- **The vendor's build changed** without declaring it, or at all for an
  open-source app ([packaging levels](../project/trust.md#packaging-changes)).
- **A dependency compiled in the manifest** instead of an extra download or a
  [prebuilt stack](prebuilt.md).
- **Downloading and running unpinned code** at run time. A vendor's own updater
  writing into the app's data directory is fine.
- **`policy.proprietary` not set honestly.**
- **No legitimate purpose:** piracy, malware or trademark impersonation.
