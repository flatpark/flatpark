---
description: Changing many packages at once, such as a runtime upgrade or a prebuilt re-cut, and how to test it by sampling each stack.
order: 3
---

# Batch changes

Some changes touch many packages at once: moving the catalog to a new runtime
version, re-cutting a prebuilt stack, changing a pattern every app of one kind
shares. Testing every app by hand would take days, and not testing them ships
the same bug to all of them.

The rule: run the automatic checks on **every** affected app, and the full
[testing playbook](testing-playbook.md) on **one app of each stack** (Electron,
Tauri, Qt, GTK, Java, .NET, Flutter, …). A problem in the sample means checking
every app of that stack before merging. Apps built the same way break the same
way, so one real test per stack finds what a hundred automatic ones miss.

This worked when the catalog moved to GNOME 51: a transparent Tauri window drew
wrong right after the upgrade, every Tauri app was checked, two more were found,
and all three were fixed within hours.

The catalog never splits across two versions of a runtime: every app moves, so
users keep one copy on disk. An app that can't move is a question for the
maintainer, not a quiet exception.

## For agents

### What counts as a batch

- A runtime major for a group of apps (`runtime-version`, and `base-version` for
  apps on a base app).
- A re-cut prebuilt stack, re-pinned in every consumer.
- A change to a shared pattern: the same `finish-args`, wrapper line or unpack
  step across many apps (for example a media-name grant across the Electron
  apps).

Automatic version bumps from upstream are not batches; they go through the
unpack check only.

### Where the catalog is (2026-10)

| Runtime | Version | Base |
|---|---|---|
| `org.freedesktop.Platform` | 26.08 | 26.08 |
| `org.gnome.Platform` | 51 | freedesktop 26.08 |
| `org.kde.Platform` | 6.11 (HeidiSQL only) | freedesktop 25.08; no 26.08-based branch exists yet |

New apps start on these. A base app's version follows its runtime's
freedesktop base (`org.electronjs.Electron2.BaseApp` 26.08 for both
freedesktop 26.08 and GNOME 51 apps); a mismatched base links its own libraries
against the wrong ICU and others.

### Measuring a runtime upgrade

A new runtime major is not a superset of the old one. From freedesktop 25.08 to
26.08 (GNOME 50 to 51), ICU, ffmpeg, Python, nettle, vpx, fmt, glslang and
SvtAv1Enc all changed major versions, and `libyaml`, `libxmlb`, `libappstream`
and `libSDL2_mixer` disappeared; GNOME 51 also dropped `libhandy-1` and the
gcr 3 / gck 1 libraries. Measure every app before changing a line.

On a branch with the new version set in the manifests, unpack every payload
against the new runtime (`INSTALL_RUNTIME=1 ./scripts/check-apply-extra.sh <app-id>`),
then run two checks over the unpacked tree and the built `/app`:

1. **Sonames.** A library is a regression only if all four hold: it is in a
   binary's `DT_NEEDED`; the app doesn't carry it itself (its own copies resolve
   through its RUNPATH and never reach the runtime); the new runtime lacks it;
   the old runtime has it. Drop the last condition and every gap that already
   existed reads as a new failure.
2. **Interpreter ABI.** A payload that imports compiled modules with the
   *runtime's* Python is tied to that Python's minor version, and breaks with no
   soname change at all. Look for `*.cpython-3XX-*.so`, `*.cpython-3XX.pyc` and
   the tags in `*.dist-info/WHEEL`. When upstream publishes builds per
   distribution, pick the one built for the new Python (HiresTI moved from the
   Debian 13 build to the Ubuntu 26.04 one).

What neither check sees: the **wrapper**. A variable that was right on the old
runtime can be wrong on the new one (GNOME 51 needs WebKit acceleration where
GNOME 50 didn't). That is what the per-stack sample is for.

### Prebuilt stacks move with the runtime

Each stack is built against one SDK, and its file name says which. A runtime
upgrade re-cuts every stack its apps use, in dependency order (`tesseract`
after `leptonica`; `wemeet-screenshare-hook` after `opencv-imgproc`), and
re-pins every consumer.
Re-pin `url`, `sha256` **and** `size` together: a stale size builds green and
fails every install and update with "Wrong size for extra data". See
[prebuilt stacks](../packagers/prebuilt.md#a-stack-per-runtime-base).

### Running the batch

1. Change the versions on a branch, measure (above), and list the apps that
   need more than the version change.
2. Re-cut and re-pin prebuilt stacks.
3. Build every affected app.
4. Run the unpack check on every app.
5. Pick one app per stack, preferably one with the stack's riskiest features
   (a transparent window, a tray, media), and run the whole
   [testing playbook](testing-playbook.md) on it.
6. A failure in a sample: find the cause, list every app of that stack that
   shares it (from manifests and upstream config, such as `transparent` in
   `tauri.conf.json`), test and fix them in the same batch.
7. Record what was sampled and what was found in the PR; add any new problem to
   the [incident list](../reference/incidents.md).

A batch PR is reviewed like any change we make to packages; it doesn't need a
second reviewer unless it also changes a principle or the infrastructure.
