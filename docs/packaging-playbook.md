# FlatPark packaging playbook — end-to-end spec

The **canonical process** for taking an app from *"found a candidate"* to *"packaged,
tested, listed, and upstream informed."* **Every packaging run follows this.** It ties
together the pieces that already have their own docs and adds the parts that don't:

- **Discovery detail** (crawl queries, gates) → [`discovery-pipeline.md`](discovery-pipeline.md)
- **Descriptor / manifest schema, local build & test, auto-update resolver** →
  [contributing guide](https://flatpark.org/contributing/)
  (source: [`site/src/content/pages/contributing.md`](../site/src/content/pages/contributing.md))
- **The review bar a PR is graded against** → [`pr-review.md`](pr-review.md)

This file is the **spine**; those are the deep dives. Where they conflict, **this file wins**
and the other should be updated to match.

---

## 0. Golden rules (read every time)

1. **Repackage the official binary, unmodified.** extra-data only — fetch the vendor's
   own release, unpack it, wrap it. Never patch or recompile the payload. Adapting it to
   the sandbox from the *outside* — wrapper env, extra modules for missing libs, `PATH`
   shims — is fine; the bytes that run must still be the vendor's.
2. **Nothing an app fetches goes into R2 except a shared `flatpark/prebuilt` stack.**
   `type: archive` / `type: git` / any remote source that lands bytes in `/app` bakes
   those bytes into the flatpak ref and ships them from `dl.flatpark.org` (R2) — we pay
   for that storage and bandwidth. The **only** sanctioned exception is a reusable,
   multi-app support stack released from [`flatpark/prebuilt`](https://github.com/flatpark/prebuilt)
   (the Ayatana tray stack, `appimage-tools`, the mpv/sql/opencv stacks, …), consumed as a
   pinned archive module. **Everything else — the app payload and any sizeable single-app
   dependency — is `extra-data`**, downloaded from the vendor / release URL at install
   time so the bytes never touch our repo. A missing library that's genuinely shared by
   several apps → add one reproducible release to `flatpark/prebuilt`, don't source-build
   it per app.
3. **Rank by fit, not stars.** Not-on-Flathub + clean sandbox/extra-data + maintained +
   genuinely useful. >~200 stars is already "popular enough."
4. **Describe only what *our* package does.** Do **not** claim upstream is broken, needs a
   workaround, or that we "fix"/"sidestep"/"avoid" their bug — in manifest comments, PRs,
   **or** upstream messages. See §7.1; this is a hard rule (we've already had to walk one
   back publicly).
5. **The review gate — two outward-facing actions require an explicit human OK first:**
   **(a) opening a PR to this repo, (b) posting anything to an upstream repo.** Prepare
   everything, **present the draft, then wait.** Internal steps (branch, commit, push,
   local build/test) don't need the gate.
6. **Never open a PR for an app you haven't run.** Build it, `flatpak install` it into the
   isolated test installation, launch it, exercise the core feature (§4). A manifest that
   only validates is not tested.
7. **Never post upstream until the package is live and smoke-tested.** A 404 install link
   or a crash-on-launch is worse than staying silent — especially with maintainers already
   sensitive about AI-assisted work.
8. **Never self-merge.** Open the PR; leave the merge to the maintainer.
9. **De-list on request, no argument.** If an upstream says "please don't," remove it right
   away and don't re-post.

---

## 1. Discover — two channels

Full crawl queries live in [`discovery-pipeline.md`](discovery-pipeline.md) §1–2. In short:

- **Community (high-star, not on Flathub).** Apps shipping an official Linux GUI binary,
  searched by GitHub topics (`topic:linux topic:electron/tauri/gtk/qt/...`). Weaker demand
  signal, but real products.
- **Flathub `AI Slop`-labelled PRs.** Rejected on policy grounds (AI-authored manifest,
  "must build from source") — often *real* apps in exactly FlatPark's niche. Higher demand
  signal (someone already tried to submit it).
  `gh api search/issues -f q='repo:flathub/flathub is:pr label:"AI Slop" created:>=<date>'`

**Per candidate, record demand + prior art** (drives go/no-go and the §7 comment):
- Upstream tracker: search their own issues for Flatpak/Flathub requests + the **maintainer's
  stance** (their concerns reveal real blockers).
- Prior Flathub PRs for this app and **why they closed**.

Re-run these crawls on a **periodic cadence** — the point is catching newly-released apps and
freshly-rejected Flathub PRs, not a one-off sweep.

## 2. Gate — feasibility (apply BEFORE packaging)

The hard gates (detail in [`discovery-pipeline.md`](discovery-pipeline.md) §3):

1. **Not on Flathub.** Verify by **name** via Flathub search **and** `/api/v2/appstream/<id>`
   404 — don't trust a guessed app-id (PixiEditor slipped through once by only checking the
   `com.` variant).
2. **Self-contained official Linux binary — `.deb`/`.rpm`/`.tar.gz`/zip/official installer
   /AppImage.** These unpack offline with the runtime's `bsdtar`/`tar`. **AppImage is now
   accepted** — a type-2 AppImage is an ELF stub + an appended SquashFS, and the
   `appimage-tools` prebuilt cracks it offline (no libfuse, never executed); recipe in §3.
3. **Self-contained for its CORE feature.** Reject if the headline function shells out to a
   host toolchain/daemon not in the sandbox (killed: NetPad→.NET SDK, quickgui→qemu).
4. **No Linux caps `finish-args` can't grant** (`CAP_NET_RAW`/`CAP_NET_ADMIN` → packet
   capture / VPN are structurally impossible).
5. **License / content policy.** Proprietary is fine *with* the `policy.proprietary` flag;
   streaming/downloader/content apps are P2 (ToS/copyright review first).

Neither the toolkit nor the license is a gate: Electron and Tauri apps are welcome
(recipes in §3), as are closed-source ones. Upstream shipping a `.deb`/`.rpm`/tarball/zip/
official installer is what qualifies an app.

## 3. Package

Detail + schema in the [contributing guide](https://flatpark.org/contributing/). The shape:

- **Inspect the artifact.** Extract (`bsdtar` for `.deb`/zip, `tar` for tarball), check
  `readelf -d` NEEDED against the runtime's coverage, locate the icon / `.desktop` / metainfo,
  find the largest icon available.
- **Always unpack with `--no-same-owner`.** For a *system-wide* install Flatpak runs
  `apply_extra` as **root with `--cap-drop ALL`**, so it cannot `chown` to whatever uid the
  archive recorded. Both `bsdtar` and `tar` restore ownership by default under uid 0, and the
  resulting `EPERM` aborts the unpack — every member extracts, yet the install dies with
  `apply_extra script failed, exit status 256`. It never reproduces under `--user`, where the
  script runs as you and ownership is never restored. Artifacts built without `fakeroot` carry
  a real uid (`1000`, `1001`, …) and trip this; `.deb`s from a proper `dpkg-deb` do not, which
  is why it hides. Check with
  `bsdtar --numeric-owner -tvf <artifact> | awk '{print $3":"$4}' | sort -u`.
- **Pick the runtime.** `org.freedesktop.Platform//26.08` by default; `org.gnome.Platform//51`
  for GTK / WebKitGTK / Tauri. **Always the major the rest of the catalog is on** — match what
  the existing manifests pin, never an older major to dodge a build break. A single straggler
  forces every user to keep a second runtime major on disk. If an app genuinely can't run on the
  current major, that's a **flag-and-ask**, not a quiet downgrade.
  - **Where the catalog stands (2026-09-19).** The freedesktop apps are on `//26.08` and 43
    GTK / WebKitGTK / Tauri apps are on `org.gnome.Platform//51`, both freedesktop 26.08
    bases. Five apps are held back, each for its own reason:
    - *Runtime-level blockers.* `com.usebottles.bottles` — its payload is built by
      [`flatpark/bottles-release`](https://github.com/flatpark/bottles-release) against the
      runtime's own interpreter and carries `cpython-313` extension modules and `.pyc`, so it
      moves only when that pipeline is rebuilt on Python 3.14. `yara-python` has no cp314
      wheel, so that means building it from its sdist; this may simply stay on 50.
      `dk.nikse.subtitleedit` and `site.harbor.Harbor.Beta` — both consume `prebuilt`'s
      `mpv-stack`, and mpv v0.40.0 does not compile against the ffmpeg 8 in the 26.08 base
      (the `FF_PROFILE_*` aliases are gone). Re-cutting that stack means moving mpv to
      v0.41.0, which is its own change.
    - *Held for unrelated upstream drift.* `sh.loft.devpod` — its `apply_extra` reads
      `/app/bin/devpod-cli`, which that sandbox never binds (it binds only `/app/extra`), so
      a system-wide install cannot succeed today. That is a bug to fix, not a runtime
      question, and it wants its own change.
    - *No runtime to move to.* `com.heidisql.HeidiSQL` — on `org.kde.Platform//6.11`; Flathub
      publishes no 26.08-based KDE branch.

    New apps enter on 26.08 / 51.
  - **An app id follows upstream's own identifier — so a rename is a new package, not an
    edit.** Where upstream ships its own Flatpak or, for a Tauri app, declares a
    `src-tauri/tauri.conf.json` `identifier`, that is the id; reusing it is how a FlatPark
    package and an upstream one stay the same application rather than two rival refs. When
    upstream renames itself it changes that identifier, and since a Flatpak ref is keyed on
    the app id, **users do not migrate automatically**. So do not rewrite the existing
    directory in place: add the new id as its own `registry/<id>/` and keep the old one
    listed until the rename has finished landing upstream, then de-list it.
    `dev.aninsomniacy.rayburst` is the worked example — upstream renamed Motrix Next to
    *Rayburst* and its identifier to `dev.aninsomniacy.rayburst` in v4.0.0-beta.1, and says
    itself that moving over is a fresh installation with no data import. The new package
    tracks the 4.x line (its resolver deliberately includes prereleases, since 4.x has no
    stable release yet); `com.motrix.next` stays for the 3.9.x line that still ships under
    the old name. An approval carries across a rename — cite the original link and say so in
    the new row (see [`upstream-approvals.md`](upstream-approvals.md)).
  - **Bumping a runtime major is a measurement, not an assumption.** A new major is not a
    superset of the old one: across 25.08 → 26.08 (and so 50 → 51) ICU went 77 → 78, ffmpeg
    61 → 62, Python 3.13 → 3.14, nettle/hogweed, vpx, fmt, glslang and SvtAv1Enc all jumped a
    major, and `libyaml`, `libxmlb`, `libappstream`, `libSDL2_mixer` and (in GNOME 51)
    `libhandy-1` and the gcr3/gck1 trio went away outright. Two checks per app, and both
    matter — the soname one alone passed an app that then could not start:
    - **Sonames.** A payload regresses when a `DT_NEEDED` entry is *in* its closure, *not* in
      the app's own tree (anything it carries resolves through its rpath and never reaches
      the runtime), *absent* from the new runtime, and *present* in the old one. Miss that
      last clause and every pre-existing gap reads as a fresh regression.
    - **Interpreter ABI.** A payload that imports compiled extension modules with the
      *runtime's* interpreter is pinned to that interpreter's minor version, and no soname
      changes when it breaks. Look for `*.cpython-3XX-*.so` and `*.cpython-3XX.pyc` in the
      unpacked payload and for wheel tags in `*.dist-info/WHEEL`. `com.hiresti.player` moved
      from upstream's debian13 `.deb` to their ubuntu2604 one for exactly this reason.
    Unpack every payload against the *new* runtime (`scripts/check-apply-extra.sh` does the
    unpack the way a system-wide install does) and run both checks over the result plus the
    built `/app` tree, so archive-module stacks are covered too.
  - **Prebuilt stacks move with the runtime.** A [`flatpark/prebuilt`](https://github.com/flatpark/prebuilt)
    stack is built against one SDK major and its release artifact is named for it, so a
    runtime bump means re-cutting every stack the batch touches and re-pinning URL + sha256
    in each consumer. Cut them in dependency order — a stack that builds against another
    (`ffmpeg-full` on x264/x265/lame/rubberband/libass, `tesseract` on `leptonica`) needs its
    dependency's new release pinned first.
- **Tech recipes.**
  - **Electron** → `base: org.electronjs.Electron2.BaseApp//<ver>`, run via `zypak-wrapper`
    so Chromium keeps its **internal sandbox through Zypak's default entrypoint** (do **not**
    reach for `--no-sandbox`), plus `--unset-env=ELECTRON_RUN_AS_NODE`. Template:
    [`registry/pro.affine.AFFiNE`](../registry/pro.affine.AFFiNE),
    [`registry/org.electerm.Electerm`](../registry/org.electerm.Electerm).
  - **Tauri / WebKitGTK** → `WEBKIT_DISABLE_DMABUF_RENDERER=1` in the wrapper (else blank
    window). **Check the app's `tauri.conf.json` for `transparent: true` first, because then
    that rule inverts.** On `org.gnome.Platform//51` a transparent, undecorated window whose
    web view runs unaccelerated never paints its background: the window is see-through onto
    the desktop and content only flashes while scrolling or zooming. It is not a driver
    problem and forcing XWayland does not help; the same payload renders on `//50` either
    way. Such an app needs the accelerated path left **on** —
    `WEBKIT_DISABLE_DMABUF_RENDERER=0` and `WEBKIT_DISABLE_COMPOSITING_MODE=0`, written as
    `${VAR:-0}` so a `flatpak override --env=` can still take it back. Worked example:
    [`registry/dev.aninsomniacy.rayburst`](../registry/dev.aninsomniacy.rayburst). Opaque
    Tauri windows are unaffected, which is why most of the catalog's Tauri apps moved to 51
    without noticing. If the app has a **tray icon**, Tauri's `tray-icon` `dlopen`s
    libayatana-appindicator and *panics* when it's absent — the GNOME runtime doesn't ship
    it. **Do not duplicate the five-module Ayatana source build in each app.** Consume the
    pinned `ayatana-stack` archive from [`flatpark/prebuilt`](https://github.com/flatpark/prebuilt)
    as a normal module before the app module; copy the current URL and SHA-256 from
    [`registry/com.ccswitch.desktop`](../registry/com.ccswitch.desktop). The archive is built
    against a specific GNOME SDK major, so migrate it explicitly when the catalog runtime
    major changes. Add `--filesystem=xdg-run/tray-icon:create` only when the app actually
    exposes a tray icon. If another missing open-source support stack is shared by multiple
    apps, prefer one reproducible release in `flatpark/prebuilt` over per-app copies.
  - **Host-dependent behavior** (the app shells out to host tools or probes `/proc`) → adapt
    from the *outside*, never by patching the payload: wrapper env, `PATH` shims that
    `flatpak-spawn --host` the tool, an `LD_PRELOAD` shim. Reference:
    [`registry/io.enpass.Enpass`](../registry/io.enpass.Enpass) (`lsof`/`readlink`/`cat`
    shims + a `getpid` override for browser-extension validation). This costs
    `--talk-name=org.freedesktop.Flatpak` — declare it in `policy.dangerous_permissions`,
    justify it, and expect human review; it is otherwise an auto-reject.
  - **Bundled JRE** (Java desktop apps) → [`registry/com.interactivebrokers.ibkrdesktop`](../registry/com.interactivebrokers.ibkrdesktop),
    which fetches a Zulu JRE tarball as a second extra-data source and stages it at
    `/app/extra/jre` for the wrapper to exec.
  - **AppImage** → the `.AppImage` is the app's extra-data payload; add
    [`flatpark/prebuilt`](https://github.com/flatpark/prebuilt)'s **`appimage-tools`**
    release as a **second extra-data source** (copy the current URL + SHA-256 from
    [`registry/is.folo.Folo`](../registry/is.folo.Folo)). Never runs, never needs libfuse.
    In `apply_extra`, unpack `appimage-tools` with `bsdtar`, then crack the SquashFS
    appended to the stub:
    ```sh
    off=$(appimage-tools/bin/appimage-offset app.AppImage)
    appimage-tools/bin/unsquashfs -o "$off" -d app app.AppImage
    ```
    Wrap the AppDir's own launcher — read its name out of the bundled `.desktop` `Exec=`
    (electron-builder names it after `productName`), symlink a stable one, don't hardcode.
    `unsquashfs` here handles gzip/xz/lz4/zstd but **not LZO** (needs a lib the runtime
    lacks; almost no AppImage uses it). Recipes: Electron AppImage →
    [`registry/is.folo.Folo`](../registry/is.folo.Folo) (`base:
    org.electronjs.Electron2.BaseApp` + zypak); Qt5 AppImage →
    [`registry/org.openshot.OpenShot`](../registry/org.openshot.OpenShot) — bundled Qt5
    wayland plugins often omit `libQt5WaylandClient.so.5`, so pin `QT_QPA_PLATFORM=xcb`
    + `--socket=x11` and unset `QT_QPA_PLATFORM`. `--persist=<dotdir>` is silently
    ignored when `--filesystem=home`/`host` is also granted — grant only `xdg-*` subdirs
    so `$HOME` stays the per-app dir.
  - Version-stamped top dir → rename to a stable path in `apply_extra`.
  - **Don't hardcode a name the payload owns.** Pin refreshes are automated, so any
    name upstream can change between releases — above all the launcher binary — must be
    read out of the artifact rather than written into the unpack script or the wrapper.
    A `.deb`'s own `.desktop` `Exec=` is the authoritative answer for Electron builds.
    `com.tldraw.Offline` learned this the hard way: v1.12.0 renamed the launcher and the
    refreshed pin shipped an app nobody could install
    ([#130](https://github.com/flatpark/flatpark/issues/130)).
- **Descriptor set** under `registry/<app-id>/`: `flatpark.yml`, `<id>.yml`, `<id>.metainfo.xml`,
  `<id>.desktop`, `<id>.png`, `apply_extra.sh`, `<app>-wrapper`, `resolve-update.sh`.
- **Permissions:** tightest `finish-args` that work. Don't pre-grant broad host access;
  document optional caps (`~/.ssh`, `--device=all`, `--filesystem=home`) as opt-in
  `flatpak override` in the **metainfo**, not in `finish-args`.
- **metainfo:** mark it a **community package** ("repackages the official upstream build
  unmodified"), honest `project_license`, screenshot `<image>` URLs pointing **at upstream**
  (never upload to R2). The site's `enrich` step downloads those and serves recompressed webp
  from Pages — a CDN win, and it drops the upstream fetch from page load — falling back to the
  upstream hotlink only if the fetch fails.

## 4. Test / verify — every run, no exceptions

1. `node scripts/read-descriptor.mjs registry/<id>/flatpark.yml` and
   `node scripts/audit-descriptor.mjs registry/<id>/flatpark.yml` (exit 0).
2. Build: `scripts/build-app.sh <id>` (or `flatpak-builder --install` for a quick loop).
   **`appstreamcli compose` must print `Success`.**
3. Install from the signed local repo into an **isolated** `--installation=test` so it never
   pollutes your everyday Flatpak state (recipe in the contributing guide). Installing
   exercises `apply_extra` (the extra-data download + unpack).
4. `scripts/check-apply-extra.sh <id>` — runs `apply_extra` as **root with every capability
   dropped**, which is what a *system-wide* install does and what step 3 never reaches (a
   custom installation runs it as you). It downloads the pinned artifact, checks its sha256,
   and unpacks it in that sandbox. CI runs it wherever a payload is new to the unpack
   script: `pr-checks` for any PR whose `sha256` moved, and the two update workflows
   before they pin a fresh upstream artifact (`INSTALL_RUNTIME=1` lets those fetch the
   runtime without building first). A held-back pin in an auto-update PR means this
   check failed — the app keeps its last installable version until the script is fixed.
5. **Smoke-test the actual launch:** the app must start, and its data must land inside the
   sandbox (`~/.var/app/<id>/…`). Confirm no missing libs (`LD_TRACE_LOADED_OBJECTS=1` → 0
   "not found"). Note in the PR anything you *couldn't* verify (GUI render on a real session,
   login flows, hardware paths) — coverage is always partial and honesty about that matters.

## 5. Branch & commit format

- **Never commit to `main`.** Branch first.
  - New app: **`add/<app-id>`** (e.g. `add/com.triliumnext.notes`).
  - Fix/change: **`fix/<slug>`** or **`docs/<slug>`** (e.g. `fix/trilium-sandbox-note`).
- **Conventional Commits.** Subject: `<type>(<short-name>): <summary> (<app-id>)`.
  - New app → **`feat(<short>): add <App> <one-liner> (<app-id>)`**
    (e.g. `feat(trilium): add Trilium Notes knowledge base (com.triliumnext.notes)`).
  - Fix → **`fix(<short>): <what> `** (e.g. `fix(trilium): correct the zypak/sandbox comments`).
  - Body: *why*, not a file list. If you're correcting an earlier claim, say what was wrong.
- **Trailer** on every commit:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **Rebase onto `origin/main`** before pushing.

## 6. PR format

- **Title** = the commit subject.
- **Body** — the house "packaging notes" shape:
  - **What** — one line: the app + app-id.
  - **Why this fills a gap** — not-on-Flathub / abandoned Flathub entry / rejected Flathub PR;
    the demand you found in §1.
  - **Packaging** — runtime, extra-data source, recipe (Electron/zypak/etc.), app-id choice.
  - **Sandbox** — the `finish-args` and what's deliberately withheld. Justify anything
    broad you kept; for what you withheld, point at the `flatpak override` lines in the
    metainfo that let a user opt in.
  - **Verification** — the §4 checklist as ticked items (the local `flatpak install` +
    launch is mandatory before the PR), plus what's still unverified.
  - If you walk back a claim later, add a short **Correction** footer pointing at the fix PR.
- **Footer:** `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **Review gate:** draft the PR body, **present it, open (`gh pr create`) only on approval.**
  **Never self-merge** — the maintainer merges.

## 7. Engage upstream

Only after the package is **live + smoke-tested** (Golden rule 7). Reuse what §1 found
(demand + the maintainer's stated concerns).

### 7.1 The hard rule: no inaccurate or disparaging claims

Describe **only what our package does**. Before writing any comparison to upstream's own
build, **verify it against current upstream**: is the issue still open? Is a fix already
merged, and by whom? (We once told a maintainer our zypak setup "sidesteps their `--no-sandbox`
launch bug" — the bug had been fixed months earlier *by that same maintainer*. It didn't change
the outcome but it read as ignorant/disparaging and had to be corrected publicly.) When in
doubt, **drop the comparison.** A "packaging note" should *offer help* (a reusable env var,
an override tip), never grade their work.

### 7.2 Where to post

- **Prefer an existing Flatpak/Flathub-request issue** on the app's own tracker (that's where
  the demand already is). Else the context of the closed Flathub PR, or a new issue.
- Issues disabled / no tracker → a low-key DM or public reply on the maintainer's channel,
  explaining *why* you're reaching out there (see the Yaak DM precedent).

### 7.3 Voice & template

Warm, professional, first-person; no slang, no emoji. The proven shape (HiresTI, Tabularis,
DiscordChatExporter, Yaak):

```
Hi @<maintainer> — thanks for <App>, it's great. I maintain **[FlatPark](https://github.com/flatpark/flatpark)**,
a small hub that offers Flatpak installs for apps that aren't on Flathub, and I've packaged <App> there.

It uses Flatpak **extra-data**, so it downloads your **official <artifact> release** unmodified at
install time and tracks new releases automatically from your GitHub releases — I don't rehost or patch
anything. <one line on what it is, e.g. "local-first desktop app, no server needed">.

<Optional: one honest line on why it helps — e.g. the Flathub PR was closed / official Flathub isn't
planned — framed as a stopgap, never as a knock on Flathub or on you.>

Install:
```
flatpak remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak install flatpark <app-id>
```
App page: https://flatpark.org/apps/<app-id>

<Optional packaging note that *helps* them — a reusable override/env tip — never a critique.>

I've only smoke-tested it myself, so my coverage is certainly incomplete — if you have time to put it
through real use and see what breaks, I'd genuinely appreciate it, and any issue or PR on the packaging
is very welcome.

If you'd be willing to make FlatPark an officially supported install method — recommending it in your
install docs, on the site, or to your community — I'd be grateful. The idea is that it takes the Flatpak
packaging and distribution research off your plate while giving your users a clean install and automatic
updates.

And if you'd rather I **not** list it, just say so and I'll remove it right away. If you're happy for it
to stay, I'll add a blue "developer-approved" shield to its FlatPark page and feature it on the homepage.
Hope this helps your users!
```

The ask, every time, has **four** parts, in this order: **(1) invite testing** and welcome issues/PRs
(be upfront that your own verification is partial); **(2) ask to be listed as an official install
method** — in their README, docs, download page or website, framed as taking distribution and
packaging-research load off them, never as a knock on how they ship today; **(3) offer the exit** →
de-list on request, no argument; **(4) request developer authorization** → on a yes, add the blue
**"developer-approved" shield** to the app page + a **homepage feature**. `@`-mention the maintainer at
the ask.

Part (2) is the one that grows FlatPark into a channel maintainers adopt deliberately rather than merely
tolerate, so it is **not** optional — a link from upstream is the thing that actually drives adoption.

**Avoid "stopgap" framing** unless the maintainer has explicitly said they are working on their own
package. Calling the listing temporary, or closing with "in the meantime", undercuts the very ask in
part (2): you cannot invite someone to adopt FlatPark officially in one paragraph and describe it as a
placeholder in another.

**Review gate:** draft the comment, **present it, post only on approval.** Don't re-post if they've
said no.

## 8. On the maintainer's response

- **Yes / approves** → add the blue "developer-approved" shield to the app page + feature on the
  homepage.
- **No** → de-list immediately; don't argue, don't re-pitch.
- **Correction / criticism** (e.g. an inaccurate claim) → acknowledge it plainly, **fix the repo**
  (manifest comments, wrapper, PR body — via a `fix/…` branch + PR) **and the offending message**,
  then reply linking the fix. Graciousness > defensiveness; the person correcting you is often the
  one who did the underlying work.

## 9. Cadence & automation

- **Re-crawl (§1) periodically** to catch new releases and freshly-rejected Flathub PRs.
- Each app's `resolve-update.sh` already lets FlatPark re-pin & rebuild on new upstream releases —
  no manual version bumps.
- **A broken upstream repackage opens an issue.** When `update-check`'s payload gate rejects a new
  artifact it holds that app's pin (users stay on the last version known to install) and
  `scripts/ci-alert.sh` opens a `ci-alert`-labelled issue naming the app — a red run in the Actions
  tab notifies nobody, an issue does. Fix `registry/<id>/apply_extra.sh`, verify with
  `./scripts/check-apply-extra.sh <id>`, and the next run closes the issue itself. A failed
  `publish` opens the same kind of issue under the `publish` key.
- **Runtime majors are NOT bumped by CI.** `update-check` only re-pins extra-data and the metainfo
  release; `runtime-version` / `base-version` are hand-pinned per manifest. When a new major lands,
  the maintainer kicks off an **AI-led batch update** that bumps and re-tests the whole catalog at
  once — so the catalog never splits across two majors (see §3, "Pick the runtime").
- The §1–§2 crawl + §2 gates are scriptable into a shortlist; §3 packaging is templated per recipe.
  Keep the **review gate** on the two outward-facing actions (§0.5) even as the rest automates.
