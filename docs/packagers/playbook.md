---
description: The full process an agent follows on every packaging run, from candidate to listed app.
order: 9
---

# Packaging playbook

The ordered steps an agent (or a person) follows to take an app from candidate to
listed. Each step links to the page that holds its rules; this page adds only
the order, the checks an agent must not skip, and the parts with no page of
their own yet. Where this page and a linked page disagree, the linked page wins.

---

## 0. Rules (read every time)

1. **What can be listed and how a package is built** are in
   [can it be packaged?](can-it-be-packaged.md), [what a package is](basics.md)
   and [permissions](permissions.md). Read them; don't work from memory.
2. **Two outward-facing actions need an explicit human OK first:** opening a PR
   on this repository, and posting anything on an upstream repository. Prepare
   everything, show the draft, then wait. Branches, commits, pushes and local
   builds need no OK.
3. **Never open a PR for an app you haven't run** (step 4).
4. **Describe only what our package does.** Never claim upstream is broken,
   needs a workaround, or that we fix their bug: not in manifest comments, PRs
   or upstream messages (§6.1).
5. **Don't merge your own PR** unless the maintainer tells you to.
6. **When workarounds start stacking, stop.** If a package needs a second or
   third workaround to run, report what you found and let the maintainer
   decide; don't keep adding them.
7. **De-list on request, no argument.** If upstream says "please don't," remove
   it right away and don't re-post.

---

## 1. Discover — two channels

Rank candidates by fit, not stars: not on Flathub, a clean sandbox and
extra-data story, maintained, genuinely useful; >~200 stars is already popular
enough. Full crawl queries live in [`discovery-pipeline.md`](../internal/discovery-pipeline.md) §1–2. In short:

- **Community (high-star, not on Flathub).** Apps shipping an official Linux GUI binary,
  searched by GitHub topics (`topic:linux topic:electron/tauri/gtk/qt/...`). Weaker demand
  signal, but real products.
- **Flathub `AI Slop`-labelled PRs.** Rejected on policy grounds (AI-authored manifest,
  "must build from source") — often *real* apps in exactly FlatPark's niche. Higher demand
  signal (someone already tried to submit it).
  `gh api search/issues -f q='repo:flathub/flathub is:pr label:"AI Slop" created:>=<date>'`

**Per candidate, record demand + prior art** (drives go/no-go and the §6 comment):
- Upstream tracker: search their own issues for Flatpak/Flathub requests + the **maintainer's
  stance** (their concerns reveal real blockers).
- Prior Flathub PRs for this app and **why they closed**.

Re-run these crawls on a **periodic cadence** — the point is catching newly-released apps and
freshly-rejected Flathub PRs, not a one-off sweep.

## 2. Check it can be packaged

[Can it be packaged?](can-it-be-packaged.md): the official download, what
works in the sandbox, Flathub overlap, the app id. Record what you found; the
PR and any upstream message use it.

## 3. Package

Write the files in [what a package is](basics.md) for the download chosen in
[choosing a format](formats/README.md); libraries the runtime lacks come from
[prebuilt](prebuilt.md); grants follow [permissions](permissions.md); known
problems are in [common problems](solutions/README.md). What has no page of its
own yet:

- **Pick the runtime.** `org.freedesktop.Platform//26.08` by default; `org.gnome.Platform//51`
  for GTK / WebKitGTK / Tauri. **Always the major the rest of the catalog is on** — match what
  the existing manifests pin, never an older major to dodge a build break. A single straggler
  forces every user to keep a second runtime major on disk. If an app genuinely can't run on the
  current major, that's a **flag-and-ask**, not a quiet downgrade.
  - **Where the catalog stands (2026-10-10).** Every freedesktop app is on `//26.08` and every
    GTK / WebKitGTK / Tauri app on `org.gnome.Platform//51`, both freedesktop 26.08 bases.
    One app is held back:
    - *No runtime to move to.* `com.heidisql.HeidiSQL` — on `org.kde.Platform//6.11`; Flathub
      publishes no 26.08-based KDE branch.

    New apps enter on 26.08 / 51.
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
- **Stack recipes and known problems** → [common problems](solutions/README.md),
  and the checklist for the app's stack in [by stack](solutions/by-stack.md).
- **metainfo:** mark it a **community package** ("repackages the official upstream build
  unmodified"; a proprietary package that injects code says what it injects instead of
  "unmodified"), honest `project_license`, screenshot `<image>` URLs pointing **at upstream**
  (never upload to R2). The site's `enrich` step downloads those and serves recompressed webp
  from Pages — a CDN win, and it drops the upstream fetch from page load — falling back to the
  upstream hotlink only if the fetch fails.


## 4. Test / verify — every run, no exceptions

Build and test as in [submitting an app](submitting.md#build): descriptor checks,
`check-apply-extra.sh`, `publish.sh --verify`, then the app installed and used.
On top of that:

- `appstreamcli compose` in the build log prints `Success`.
- No library is missing: `LD_TRACE_LOADED_OBJECTS=1` on the main binary inside
  the sandbox reports nothing "not found".
- The app's data lands under `~/.var/app/<id>/` or a granted directory, and
  survives a restart.
- `flatpak kill <id>` after every run. When the work is merged or dropped,
  clean up as in [cleaning up after a run](cleanup.md).
- Note what you couldn't verify (a real session's rendering, login flows,
  hardware). Coverage is always partial; say so.

## 5. Open the PR

Branch, commit and PR body as in [submitting an app](submitting.md#open-the-pr).
Add the trailer and footer your tool uses for AI-assisted work. Draft the body,
show it, and open the PR only on approval (rule 2).

> **Being reworked.** Steps 6 to 8 are being folded into one listing
> lifecycle: listing, testing, inviting upstream and de-listing. Until that
> page exists, they apply as written.

## 6. Engage upstream

Only after the package is **live + smoke-tested**. Reuse what §1 found
(demand + the maintainer's stated concerns).

### 6.1 The hard rule: no inaccurate or disparaging claims

Describe **only what our package does**. Before writing any comparison to upstream's own
build, **verify it against current upstream**: is the issue still open? Is a fix already
merged, and by whom? (We once told a maintainer our zypak setup "sidesteps their `--no-sandbox`
launch bug" — the bug had been fixed months earlier *by that same maintainer*. It didn't change
the outcome but it read as ignorant/disparaging and had to be corrected publicly.) When in
doubt, **drop the comparison.** A "packaging note" should *offer help* (a reusable env var,
an override tip), never grade their work.

### 6.2 Where to post

- **Prefer an existing Flatpak/Flathub-request issue** on the app's own tracker (that's where
  the demand already is). Else the context of the closed Flathub PR, or a new issue.
- Issues disabled / no tracker → a low-key DM or public reply on the maintainer's channel,
  explaining *why* you're reaching out there (see the Yaak DM precedent).

### 6.3 Voice & template

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

## 7. On the maintainer's response

- **Yes / approves** → add the blue "developer-approved" shield to the app page + feature on the
  homepage.
- **No** → de-list immediately; don't argue, don't re-pitch.
- **Correction / criticism** (e.g. an inaccurate claim) → acknowledge it plainly, **fix the repo**
  (manifest comments, wrapper, PR body — via a `fix/…` branch + PR) **and the offending message**,
  then reply linking the fix. Graciousness > defensiveness; the person correcting you is often the
  one who did the underlying work.

## 8. Cadence & automation

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
  Keep the **review gate** on the two outward-facing actions (rule 2) even as the rest automates.
