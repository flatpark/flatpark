---
description: What FlatPark is, why it exists, and how it relates to Flatpak and Flathub.
order: 1
---

# About FlatPark

FlatPark is a community Flatpak remote for apps that ship an official Linux
download: an installer, a `.deb`, a tarball or an AppImage at a stable, public
release URL. FlatPark pins that download by checksum and size, wraps it as a
Flatpak ([extra-data](trust.md)) and signs the result. When you install the
app, your Flatpak downloads the file straight from the developer's servers.
FlatPark doesn't build apps from source and doesn't host their files.

## Goal

FlatPark aims to be a Flatpak remote that runs efficiently and is easy to take
part in. Speed matters most: apps often land minutes after an upstream release,
and a fix reaches users just as fast. Every rule is weighed by two questions:
does it stop us shipping our own bugs, and does it keep that speed?

## Why it exists

- **One place to install and update.** Apps that otherwise ship only a raw
  `.deb`, `.rpm`, tarball or AppImage become installable and auto-updating
  through one remote.
- **The current runtime for every app.** When a new version of the
  freedesktop, GNOME or KDE runtime comes out, the apps on it move to it
  together and are tested, so no FlatPark app keeps an old runtime on your
  disk. Apps from other remotes may still need runtimes of their own.
- **Least privilege, shown on every page.** Each package grants what the app's
  main job needs, and its page lists every permission with a plain note on what
  it allows. Anything more is a `flatpak override` you choose to run.
- **Judged by what it does, not how it was written.** The "AI slop" label is
  rampant — Flathub PR queues, Reddit, everywhere — and it routinely dismisses
  good software with no actual review behind it. FlatPark refuses that reflex:
  every app here was built, run, and reviewed against a
  [published bar](policies.md) — the only labels we apply are ones we can
  defend.

## How it relates to Flatpak and Flathub

FlatPark is built on [Flatpak](https://flatpak.org/) and is **not affiliated
with [Flathub](https://flathub.org/)**. Flathub builds most apps from source;
FlatPark only repackages official downloads. The two are complementary.

When a developer publishes their own app on Flathub (it is verified there),
FlatPark doesn't package it again, unless the developer asks us to. When
someone else maintains the Flathub package and it is missing a feature, has
fallen behind or has stopped working, FlatPark may offer the app too, and its
description says how the two differ.

## Who runs it

FlatPark is an independent, community-run project. Its own code is MIT-licensed;
the packaged applications remain their vendors' property and are downloaded
from official sources at install time.
