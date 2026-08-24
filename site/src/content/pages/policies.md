---
title: Listing policies
description: What FlatPark accepts, the review bar, and the de-listing process.
group: Project
order: 2
---

FlatPark hosts apps that ship a public, stable release URL and can be packaged as
[extra-data](/trust/). These are the rules for getting listed and staying
listed.

## What we host

Any app with an official, prebuilt download at a stable public URL — an
installer, `.deb`, `.rpm`, or tarball. FlatPark fetches it at build, pins it by
checksum, and signs the result. It never builds the app itself from source and
never re-hosts the binary. (AppImage is not accepted.) A package may build
supporting libraries the runtime lacks from pinned source — the application is
always the vendor's own binary.

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
  older major to work around a build break is not accepted — one straggler makes
  every user keep a second runtime on disk.
- The **tightest `finish-args`** that still work. Optional capabilities are **not
  granted by default**: leave them out and document the `flatpak override`
  command that enables them in the app's description, so each user decides. A
  permission the app truly needs to function stays in `finish-args` and is
  justified in the PR.
- **Tested locally before the PR** — the submitter has built the app, installed
  it with `flatpak install`, launched it, and confirmed the core feature works.
- A stated **license** for the app.

## Vibe-coded apps

Apps built with AI assistance ("vibe coding") are welcome. They are judged on the
same bar as any other app: development history, upstream activity, and observed
quality — not on how they were written.

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
[review runbook](https://github.com/flatpark/flatpark/blob/main/docs/pr-review.md).
The trust question is **where the bytes you run come from**, not the license:

- FlatPark either verifies source-built packages against their public source, or
  repackages an **official upstream prebuilt unmodified** — the bytes you run are
  the vendor's own.
- Official prebuilts must come from the real upstream/vendor release channel. A
  binary hosted on a submitter's personal account or a mirror, or one rebuilt or
  patched during packaging, is rejected.
- Every download is pinned by `sha256` (and size), and any git source by an
  immutable commit, so a build cannot silently swap it.
- Sandbox-escape permissions (host filesystem, the Flatpak control bus) are
  rejected; broad grants must be justified.
- **Non-FOSS is allowed** — openness is not the bar. We reject on purpose, not
  license: piracy, malware, trademark impersonation, or anything illegal to
  distribute.

We don't claim every open-source prebuilt is byte-for-byte source-verified — only
that it is an official upstream build, pinned and unmodified.

## De-listing

Removal is rare and conservative. An app leaves FlatPark for only two reasons:

- it has **genuinely lost maintenance for the long term** — the official
  download URL is gone, or upstream has been silent long enough that there is
  nothing left to package; or
- **its author explicitly asks us not to distribute it.** The vendor's word is
  final: we remove the app, no argument.

An app is **never** de-listed for how it was written, what toolkit it uses, or
because someone on the internet called it slop.

Two footnotes. The security floor applies at all times, independent of the
list above: a release found to be malicious, or one demanding dangerous
permissions that cannot be justified, is removed immediately. And an app can
also leave by *graduating* — when upstream begins publishing an official
Flathub build, FlatPark's stopgap has done its job and we retire our package;
that is success, not rejection.

The process is public: an issue is opened describing the reason, a maintainer
reviews it, and on removal the app's directory is deleted from the registry and
its ref is dropped from the repo. Already-installed copies keep working until the
user uninstalls them.
