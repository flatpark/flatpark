# RFC 0001: Governance, testing channel, docs and news

- **Status:** draft, open for comment
- **Author:** @jing2uo
- **Discussion:** this PR. Comment on any line; broader points go in the conversation tab.
- **Related:** #585 (pre-release testing), #473 (upstream self-merge), #379 (upstream approvals), #599–#603 (packaging policy and levels)

## Why

FlatPark started as one person's project. Every review, merge and policy change has
gone through that person. This was fine while the catalog was small. It doesn't work now
that other people depend on it, and it doesn't work if a distribution is going to ship
the remote enabled by default.

Most of the rules already exist. They're spread across the listing policies, the trust
page, the review runbook and the packaging playbook, and much of them are enforced in
CI. What's missing is everything around the rules:

- named roles;
- a written rule for who signs off on what, which applies to the owner like everyone else;
- a place where new packages get tested before release (#585);
- one documentation section where each audience can find the parts that apply to them;
- a public record of what changed and who did it.

This RFC proposes all five. Once it's agreed, each part is implemented in its own PR.

## 1. Principles

These are the rules the project runs on. Changing one requires an RFC like this one.

1. **The registry ships extra-data only.** Every app in `flatpark/flatpark` is the
   vendor's official download, fetched at install time, pinned by sha256 and size,
   and the repository is GPG-signed. FlatPark never re-hosts a vendor's binary.
2. **Source builds live in their own public repository.** When an app is worth
   having but upstream publishes no usable Linux build, it can be built from
   upstream's source in a dedicated `flatpark/<name>-release` repository (e.g.
   `ayugram-release`). That repository's code and workflows are public, and its
   release is consumed by the registry as extra-data like any other download.
3. **Open-source apps ship unmodified.** Nothing is injected into an open-source
   app's process, and none of its files are patched or replaced. If an app can't work
   in the sandbox without that, the fix belongs upstream, and the app isn't listed
   until the fix lands.
4. **Closed-source changes are disclosed.** A closed-source app may carry an injected
   adaptation when there is no other way. Its description says plainly what was
   changed and why.
5. **Every package declares what it does to the vendor's build, and CI checks the
   declaration.** The four levels are Unmodified, Adapted, Modified and Reduced
   isolation, and each app page shows its level. An undeclared adaptation fails CI
   (`audit-descriptor` G6).
6. **Least privilege by default.** Grants are the narrowest that still work. Optional
   capabilities are left off and documented as `flatpak override` commands.
7. **Upstream has the final word on its own app,** and no special power over anyone
   else's. Upstream decides its package's configuration, including whether it is
   listed at all. The one limit is malice: code that steals data or damages the
   system is removed immediately, whoever asked for it.
8. **Judge the package, not how it was written.** AI-assisted apps meet the same bar
   as any other app. They are never refused or removed for how they were made.
9. **One runtime major across the catalog,** so users keep one copy of the runtime
   on disk.
10. **Decisions are made in public, and the rules bind everyone.** Listings,
    removals, policy changes and role changes happen in issues and PRs anyone can
    read. The owner follows the same sign-off rules as everyone else. Security reports
    are the one exception to "public first" (§8).
11. **Automate the mechanical; humans own judgment.** Version bumps that pass the
    mechanical gate merge automatically. AI-assisted review follows the published
    runbook as a tool. It is never a sign-off.

## 2. Roles

| Role | Can do | How to get it |
|---|---|---|
| **Owner** | Merges, releases, holds the signing keys and the infrastructure (R2, Pages, Worker, domain). | Currently @jing2uo. Changed only by RFC. |
| **Reviewer** | Signs off on PRs against the review runbook (§4); adds the `sid` label (§3); opens and signs off on de-listings. | Nominated in a public issue after about 5 reviews of good quality. Confirmed if no reviewer objects within 7 days. |
| **Tester** | Installs builds from `flatpark-sid` and signs off with the tester checklist. | Open to anyone: ask in the testers issue. @diogopessoa volunteered in #585. |
| **Upstream maintainer** | Final word on their own app (principle 7); self-merge within the safe surface (§5). | Listed in `config/maintainers.yml` once they confirm in public. |
| **Packager** | Anyone who opens a PR. | No sign-up needed. |

A reviewer can also act as the tester for the same PR. The author of a PR can test it,
but can't be its reviewer. The roster lives in one file and is mirrored on the site.
Anyone inactive for 6 months moves to emeritus.

## 3. Testing channel: `flatpark-sid`

#585 asks for volunteers to test packages before they go public. Today the only option
is the `.flatpak` bundle that PR CI attaches as a GitHub artifact. Downloading it
requires a GitHub login, it doesn't update when the PR changes, and it isn't signed.

**A separate remote, opt-in only.** `flatpark-sid` is its own OSTree repository at
`https://dl.flatpark.org/sid/`, with its own `.flatpakrepo` file and **its own signing
key**. It never appears in the stable remote, and stable users never see it. Only
people who choose to test add it:

```sh
flatpak remote-add --user flatpark-sid https://dl.flatpark.org/sid/flatpark-sid.flatpakrepo
flatpak install --user flatpark-sid <app-id>//sid
```

Refs are published on the `sid` branch. A tester can then keep the stable version of
an app installed next to the sid build, and switch which one launches with
`flatpak make-current`. Both versions share the app's data directory, `~/.var/app/<id>`.

**What goes in.** A PR's build enters sid when a reviewer adds the `sid` label, and
only after the PR's CI passes. Each new push to the PR updates its sid build, so
testers pick it up with `flatpak update`. When the PR merges or closes, its ref is
removed from sid. sid is never a second catalog: an app is in it only while its PR is
open.

**How it's built.** The untrusted build stays where it is: in `pr-checks`, with no
secrets. A separate privileged workflow takes that build's artifact, commits only that
app's ref into the sid repo, signs it with the sid key, and syncs it to R2. The stable
key never touches PR content. Refs are a few kilobytes each because packages are
extra-data, so the storage cost is negligible.

**Tester checklist.** The tester posts this as a PR review using a fixed template, and
it is recorded as `Tested-by:` in the merge commit:

- installs and launches without critical errors;
- the core feature works (each PR states what that is);
- file dialogs, notifications, tray and audio work, if the app uses them;
- nothing asks for access beyond what the PR declares;
- which session (Wayland or X11) and desktop it was tested on.

**Size of the work:** one new workflow plus a cleanup job, a new key, an R2 prefix, PR
template fields and a docs page. About a day or two, with no change to the stable
pipeline.

## 4. Who signs off on what

| Change | Sign-off |
|---|---|
| Version or pin bump that passes the mechanical gate | CI only (auto-merge, as today) |
| Upstream self-merge within the safe surface (§5) | CI only |
| Change to a listed package: fixes, metainfo, permissions | 1 reviewer |
| New listing | 1 reviewer + 1 tester (may be the same person) |
| A package at level **Modified** or **Reduced isolation**, whether newly listed or raised to that level | 2 reviewers |
| De-listing for a reason in §6 | 1 reviewer |
| Project process, principles, infrastructure, or a new repository (e.g. a `-release` repo) | 2 reviewers |
| A change to this table or to a role | RFC, open for at least 7 days |

**When the owner is the only reviewer.** As long as there is no other active reviewer,
whether because none has joined yet or because all have stepped down, the owner's
sign-off counts as two. As soon as one other reviewer is active, two-reviewer changes
need that reviewer's sign-off as well. The owner can't count as two while someone else
is available to review.

**Malicious code.** A release found to steal data or damage systems is pulled at
once by anyone with merge rights. No sign-off is needed. The public write-up follows
within 7 days (§8).

## 5. Upstream maintainers

Upstream decides its package's configuration. Reviewers don't override that with their
own preferences. Upstream's authority covers decisions, not the security check: a
hijacked maintainer account must not be able to ship anything it likes. #473 is
therefore split into two lanes.

**Self-merge (`/merge`, CI only).** Allowed only within the maintainer's own
`registry/<id>/`:

- new version pins, provided the download URL stays on the **same host** as the
  current one;
- metainfo text, screenshots, desktop-file fixes;
- **narrowing** `finish-args`.

Each self-merge is recorded in the news feed (§9).

**Upstream request (1 reviewer, security-only check).** Upstream opens the PR or the
issue, and a reviewer checks it for security only. Unless the change is malicious, it
is merged as asked:

- broadening permissions, or adding any grant listed under `dangerous_permissions`;
- a new download host;
- anything that raises the packaging level;
- changes to the resolver or the build steps;
- removing the app. The reviewer verifies the requester's identity, then removes it.
  No other reason is needed.

#473 already refuses resolver edits, new build steps, and anything outside
`finish-args` and the managed extra-data block. Two more checks bring it in line with
this RFC: the download host must not change, and `finish-args` may only shrink.

## 6. App lifecycle

**Listing.** Any app that meets the policies can be listed. It goes through the
review runbook, a sid test, and the sign-offs in §4. Upstream is asked once, in a new
issue, whether the listing is OK. Their public approval earns the blue shield.

**Apps also on Flathub.** FlatPark isn't a staging ground for Flathub. It has its own
rules for listing and removal, and an app being on Flathub doesn't end its listing
here.

- If the Flathub package is **published by the developer** (verified), FlatPark
  doesn't list a second package unless upstream asks for one.
- If the Flathub package is **third-party**, FlatPark may list the app when upstream
  asks, or when someone shows that the Flathub build is behind or missing something
  that works here.
- Either way, the app's description says how this package differs from the Flathub one.

Overlaps are published as a table on the site and as `/overlap.json`, so downstreams
can filter them. Bazaar's denylist, for example, can hide every overlap. A scheduled
job compares the catalog against Flathub's app list and opens an issue when a new
overlap appears.

*Current state.* Eight apps share an id with a Flathub app. Seven are third-party
packages on Flathub. The eighth, Bottles, is published on Flathub by its developers,
so under this rule it doesn't qualify. It will be removed through the normal process
once a replacement is in place.

**Renames.** We follow Flatpak's own mechanism, end-of-life rebase, and the
procedure is the same every time:

1. List the app under the new id in its own PR.
2. In the same PR, or a follow-up, delete `registry/<old-id>/` and add a line to
   `config/renames.yml`: old id, new id, date.
3. On publish, the pipeline doesn't prune a renamed ref. It commits a copy of the old
   ref marked `--end-of-life-rebase=<old-id>=<new-id>` and re-signs.
4. On `flatpak update`, installed users are offered the switch (`-y` accepts it), and
   GNOME Software follows it. On the new app's first run, Flatpak itself moves
   `~/.var/app/<old-id>` to the new id and leaves a symlink. Flatpak also writes
   `X-Flatpak-RenamedFrom` into the new desktop file, so the new package needs no
   change for any of this.
5. After 90 days, the old ref is pruned and its line is removed from
   `config/renames.yml`.
6. A news entry gives the steps and lists what doesn't move: data kept outside
   `~/.var/app`, keyring entries, and installs where the user already installed the
   new id by hand.

The first case is AeroFTP. Upstream renamed `com.aeroftp.AeroFTP` to
`app.aeroftp.AeroFTP` (axpdev-lab/aeroftp#814), and FlatPark still ships the old id.

**De-listing.** An app is removed only for one of these reasons, each through a public
issue with one reviewer's sign-off:

- upstream asks;
- maintenance is lost for the long term (the download is gone, or upstream has been
  silent long enough that there is nothing left to package);
- the package can no longer meet the principles (e.g. an open-source app that only
  works with injected code, as with AB Download Manager in #598);
- the security floor: malicious code is pulled immediately (§4); permissions that
  can't be justified go through an issue.

Nobody, the owner included, can remove an app for any other reason.

Removal uses the same machinery as a rename. The old ref isn't pruned at once: it
gets a commit marked `--end-of-life=<reason>`, so `flatpak update` tells installed
users that the app was removed from FlatPark and why. The ref is pruned after
90 days. A malicious release is the exception: it is marked end-of-life at once,
so installed users are warned on their next update, and pruned without the 90-day
wait.

## 7. Documentation: one `/docs/` section

All documentation moves under `flatpark.org/docs/`, with a sidebar on the left and the
text on the right, grouped by who is reading. The old URLs (`/policies/`, `/trust/`,
`/guide/`, `/contributing/`) redirect. The review runbook and the packaging playbook
move into the site, which becomes their single source. The repo's `docs/` keeps only
internal ops notes.

```
Docs
├─ Overview
│  ├─ What FlatPark is, and how it relates to Flatpak and Flathub
│  └─ How it works: extra-data, -release repos, pinning, signing, runtimes
├─ For users
│  ├─ Install and set up the remote
│  ├─ Reading permissions; granting optional ones
│  ├─ Packaging levels explained
│  ├─ Renamed and removed apps: what happens to my install
│  ├─ Reporting a problem: here or upstream?
│  └─ Testing new apps with flatpark-sid
├─ For app developers (upstream)
│  ├─ Getting your app listed, or asking us not to list it
│  ├─ The approval shield
│  ├─ Your package, your call: PRs, /merge and requests
│  ├─ Push-mode updates (publish-action)
│  ├─ If your app is also on Flathub
│  └─ Renaming your app id
├─ For packagers
│  ├─ Quick start and the flatpark.yml schema
│  ├─ By format: .deb · .rpm · tarball · AppImage · vendor installer
│  ├─ By stack: Electron · Tauri · Qt · GTK · .NET · Java · Flutter
│  ├─ Shared libraries from flatpark/prebuilt; source builds in -release repos
│  ├─ Sandbox problems: work around or report upstream (table below)
│  ├─ Closed-source apps: what is allowed and how to disclose it
│  ├─ Auto-update resolvers
│  └─ Testing locally
├─ For reviewers and testers
│  ├─ Review runbook
│  ├─ Tester checklist
│  └─ Labels, sid and sign-off
└─ Governance
   ├─ Principles (§1)
   ├─ Roles and people (§2)
   ├─ Who signs off on what (§4)
   ├─ Upstream maintainers (§5)
   ├─ Listing, Flathub overlap, renames, de-listing (§6)
   ├─ Security policy (§8)
   ├─ RFCs
   ├─ Code of conduct
   └─ Legal
```

The core of the packager section is a table showing where each kind of sandbox
problem goes. The first draft below is built from what we've run into so far:

| Problem | Open-source app | Closed-source app |
|---|---|---|
| Needs an env var or launch flag (`--ozone-platform`, `--password-store=gnome-libsecret`, `QT_QPA_PLATFORM`) | Workaround OK (Unmodified) | Workaround OK |
| A library or tool missing from the runtime; fonts | Add it from `flatpark/prebuilt` or as extra-data (Adapted) | Same |
| In-app updater can't work in Flatpak | Turn it off via its own setting (Adapted). If it has no switch (e.g. the Tauri updater), **ask upstream** to check `FLATPAK_ID` | Same, or disable it in the build (Modified, disclosed) |
| Writes to a hardcoded `~/.dotdir` | `--filesystem=~/.dir:create` for the app's own directory | Same |
| Needs to run host commands | PATH script via `flatpak-spawn --host` (Reduced isolation, declared) | Same |
| The app's own sandbox needs user namespaces | zypak for Chromium-based apps (Unmodified). Otherwise **ask upstream** | May turn it off (Reduced isolation, disclosed) |
| Needs code injected into its process (`LD_PRELOAD`), or files patched or replaced | **Not listed. Report it upstream** (e.g. tray PID collisions, keyrings via raw `keyctl`) | Allowed as a last resort (Modified, disclosed) |
| The vendor's installer must run at first launch | Not listed | Allowed (Modified, disclosed) |

**Language.** English is the source. User-facing pages get a zh-Hans translation, as
they do today. The rest stays English-only until someone volunteers to translate it.

## 8. Security and keys

- `SECURITY.md` and GitHub private vulnerability reporting. Reports are acknowledged
  within 72 hours.
- **Emergency pull** of a malicious release first, with a public write-up and a news
  entry within 7 days.
- **Keys:** the stable repo is signed by a CI subkey, and the master key is offline
  and never reaches CI. sid has its own key. Rotation and revocation steps get written
  down.
- **Infrastructure and continuity:** for now, the `flatpark.org` domain and its
  Cloudflare resources (R2, Pages, Workers) are provided by the owner as a personal
  donation. Once the project has trusted long-term partners, the owner is willing to
  move them into an account dedicated to FlatPark and run it under these rules, with
  more than one administrator, so that no single person is a point of failure. The
  move is technically straightforward. Doing it is a later decision, and it doesn't
  block anything in this RFC.

## 9. News

`flatpark.org/news/` is a single reverse-chronological stream. It has no chapters and
no sidebar, and it comes with RSS/Atom feeds for everything and per kind:

- **New app:** what it is, packaged by, reviewed by, tested by, packaging level.
- **Removed:** the reason, as stated in the de-listing issue, and what users should do.
- **Renamed:** old and new id, and the migration steps.
- **Upstream self-merges** and other notable package changes.
- **People:** new reviewers and testers; moves to emeritus.
- **Policy:** accepted RFCs and principle changes.

Entries for listings, removals, renames and self-merges are generated from merged PRs,
using the commit type, the PR's reviewers, `Tested-by:` and its "Reason" field. Humans
can edit the generated text. People and policy posts are hand-written Markdown.
Routine version bumps are left out, so the stream stays readable.

## 10. Rollout

| Step | What | Depends on |
|---|---|---|
| 0 | This RFC: two weeks of comment, then accept or revise | — |
| 1 | `GOVERNANCE.md` (principles, roles, sign-off table), `SECURITY.md`, PR template with `Tested-by:` and Reason fields; policies updated to match | 0 |
| 2 | `flatpark-sid` and the tester checklist; call for testers | 1 |
| 3 | #473 with the two extra checks (§5) | 1 |
| 4 | `/docs/` with sidebar and redirects; runbook and playbook moved in | 1 |
| 5 | News with RSS; overlap table and `overlap.json` | 4 |
| 6 | First reviewers and testers onboarded | 1–2 |

**Before FlatPark is enabled by default in any distribution:** steps 1–5 are done; at
least one reviewer besides the owner is active, so no two-reviewer change rests on one
person; and sid is used for every new listing.

## Questions for reviewers

1. Is the sign-off table in §4 right? Is anything missing?
2. The self-merge safe surface (§5): too wide, too narrow?
3. Should sid also carry risky updates to listed apps (runtime bumps, packaging
   changes), or only new listings?
4. Is anything missing from the docs outline (§7) for your audience?
