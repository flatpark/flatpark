---
description: What FlatPark accepts, the review bar, and the de-listing process.
order: 3
---

# Listing policies

FlatPark hosts apps that ship a public, stable release URL and can be packaged as
[extra-data](trust.md). These are the rules for getting listed and staying
listed.

## What we host

Any app with an official, prebuilt Linux download at a stable public URL: an
installer, `.deb`, `.rpm`, tarball, zip or AppImage. When a package is added or
updated, CI downloads the file once to record its checksum and size; FlatPark
signs the result. Users' Flatpak then downloads the file from the vendor's own
URL at install time. FlatPark's own storage holds only the small package around
it, never the app. AppImages are unpacked offline (their appended filesystem is
read directly, never executed).

FlatPark doesn't build apps from source: an official release makes it
unnecessary, and source builds would cost CI time and storage for every update.
We assume that people install an app because they trust its developer. When an
app people want has no official Linux release, needs a complex build, or only
installs through an individually maintained installer, a public
[build repository](../packagers/basics.md#build-repositories) may publish the release instead,
built the way upstream builds it, unmodified and within upstream's licence; the
package uses that release as extra-data like any other download. Upstream
doesn't know about these builds, so the package's support links point at the
build repository, or at least at FlatPark, never at upstream.

**Open-source apps run exactly as upstream ships them.** Nothing is injected into
the app's process — no `LD_PRELOAD` shim, no patched or replaced files. A wrapper
may set environment variables or launch flags, and missing libraries may be
added, but if an open-source app can't work in the sandbox without injected
code, the fix belongs upstream and the app isn't listed until then. Bugs go to
upstream, except for apps from a build repository, whose bugs go to that
repository. **Closed-source apps** may carry an adaptation when there is no other
way to make a feature work; it is reviewed, the app's page shows it, and the
description says plainly what it is and why.

Toolkit and license don't gate a listing. **Electron and Tauri apps are welcome**
— the registry already ships both — and so are **closed-source apps**. If
upstream publishes a `.deb`, `.rpm`, tarball, zip, or official installer, it can
be packaged here.

## Requirements

- A **stable, public release URL** for the official build (not behind a login).
- An **AppStream metainfo** file (`<id>.metainfo.xml`) with id, name, summary,
  license, and at least one description paragraph.
- The **id matches reverse-DNS** and the registry directory name.
- The **current runtime major**, matching the rest of the catalog. Pinning an
  older major to work around a build break is not accepted.
- The **tightest `finish-args`** that still work. Optional capabilities are **not
  granted by default**: leave them out and document the `flatpak override`
  command that enables them in the app's description, so each user decides. A
  permission the app needs to function stays in `finish-args` and is justified
  in the PR. A broad grant (home, host commands) can be the default after
  review, when the app's main feature needs it or leaving it out would take
  more overrides than a user can be expected to manage.
- **Tested before the PR**: the submitter has built the app, installed it,
  launched it and used its main feature, and the PR says honestly what was
  tested and what wasn't.
- A stated **license** for the app.

## Vibe-coded apps

Apps built with AI assistance ("vibe coding") are welcome and get no special
treatment, in either direction. Like every app, they are judged on what they
do, how well they do it, whether people want them (requests, bug reports,
users) and whether they are developed and released normally. Star counts and
the project's age don't matter.

We take a side here. The "AI slop" label is everywhere now — Flathub's PR
queue, Reddit threads, all over the internet — slapped onto working software
with no review behind it: nobody built it, nobody ran it, nobody read a line of
the diff. That reflex is not quality control. It is the laziest possible
review, and it tells you nothing about the software. If anything deserves the
name, the drive-by label is the slop.

FlatPark's answer is to do the work the label skips: every submission is built,
installed, launched, and reviewed against the published bar above. Judge the
package, not the tooling that wrote it.

And we use the tools ourselves, openly. AI agents are welcome — encouraged —
for rigorous testing, thorough documentation, and automated maintenance
pipelines; FlatPark's own review and update pipeline is AI-assisted. What
matters is the bar the result clears, not the hands on the keyboard.

## Review

Every submission is reviewed (AI-assisted) against a published
[review runbook](../reviewers/review-runbook.md).
The trust question is **where the bytes you run come from**, not the license:

- FlatPark repackages an **official upstream build, unmodified**: the bytes you
  run are the vendor's own. Code injected into an app's process is rejected for
  open-source apps, and is reviewed and disclosed for closed-source ones.
- Official builds must come from the real upstream/vendor release channel. A
  binary hosted on a submitter's personal account or a mirror, or one rebuilt or
  patched during packaging, is rejected.
- Every download is pinned by `sha256` and size, so a build cannot silently
  swap it.
- Permissions that reach outside the sandbox (running host commands, the whole
  host filesystem) must be declared and argued in the PR, and a maintainer
  reviews them. They are granted only when the app's feature needs them, and
  the app page marks them with a warning.
- Review looks for obvious malicious behaviour in what is shipped: persistence,
  miners, reverse shells, downloading and running unpinned code. It doesn't
  audit the app's source.
- **Non-FOSS is allowed** — openness is not the bar. We reject on purpose, not
  license: piracy, malware, trademark impersonation, or anything illegal to
  distribute.

## De-listing

An app leaves FlatPark when:

- **its developer asks.** The developer's word is final: we remove the app, no
  argument;
- **upstream has stopped:** development ended, the repository was deleted, or
  the official download is gone;
- **a release is malicious** or damages users' systems; it is removed at once
  ([security](security.md));
- **its main feature can't work in the sandbox** and can't be fixed. An app
  that works with some features missing can stay, and its description says
  what doesn't work (a proxy client without TUN mode, for example).

An app is **never** de-listed for how it was written, what toolkit it uses, or
because someone on the internet called it slop. It isn't removed because its
developer later publishes it on Flathub either, unless the developer asks.

To remove an app, a PR deletes its directory from the registry and says why,
linking the request or issue. Once it is merged, the app is gone from the
catalog, and the weekly `delist-prune` job drops its refs from the repository.
Already-installed copies keep working until the user uninstalls them.
