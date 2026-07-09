---
title: About FlatPark
description: What FlatPark is, why it exists, and how it relates to Flatpak and Flathub.
group: Project
order: 1
---

FlatPark is a community Flatpak hub for apps that ship as a definitive download —
an official installer or prebuilt archive at a stable, public release URL.
FlatPark fetches that release at build time, repackages it as a Flatpak
([extra-data](/trust/)), pins it, and signs the result. It never builds the app
itself from source.

## Why it exists

- **One runtime version, always the latest.** Every app targets the *current*
  major of its runtime — never one app on GNOME 49 and another on 50. Old majors
  sit unused on your disk, so the whole catalog moves forward together and you
  keep just one copy.
- **Sandboxed and out of your home directory.** Flatpak keeps each app
  sandboxed; FlatPark keeps the permissions tight and surfaces them on every
  app page.
- **One place to install and update.** Apps that otherwise ship only a raw
  `.deb`, `.rpm`, or tarball become installable and auto-updating through one
  remote. (AppImage is not accepted — see [listing policies](/policies/).)

## How it relates to Flatpak and Flathub

FlatPark is built on [Flatpak](https://flatpak.org/) and is **not affiliated
with [Flathub](https://flathub.org/)**. Flathub builds most apps from source;
FlatPark deliberately only repackages official downloads (extra-data). The two
are complementary — if an app is on Flathub, install it there.

## Who runs it

FlatPark is an independent, community-run project. Its own code is MIT-licensed;
the packaged applications remain their vendors' property and are fetched from
official sources at install time.
