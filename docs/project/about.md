---
description: What FlatPark is, what it believes, and how it relates to Flatpak and Flathub.
order: 1
---

# About FlatPark

FlatPark is a community Flatpak remote for apps that ship an official Linux
download: an installer, a `.deb`, a tarball or an AppImage at a stable, public
release URL. FlatPark pins that download by checksum and size, wraps it as a
Flatpak ([extra-data](trust.md)) and signs the result. When you install the
app, your Flatpak downloads the file straight from the developer's servers.
FlatPark doesn't build apps from source and doesn't host their files.

Some apps are published by their developers. Many more are packaged by the
community because users need them: apps whose vendor only ships an installer
from its own site and has never thought about Flatpak. Either way, the bytes are
the vendor's own, and apps usually update within minutes of an upstream
release.

## Mission

**Installing apps on Linux should be easy.**

- Every developer can put their app straight into the hands of Linux users.
- Every app a user wants can be found on FlatPark.

## What we believe

1. **Plenty of software is a good thing.** AI has made software easier to write
   than ever, and the Linux desktop has more apps than it has ever had. Some
   are weekend projects nobody maintains, but on the whole the gain far
   outweighs that. An ecosystem has never suffered from too much software.
2. **Publishing is the developer's right.** Putting up a web page needs nobody's
   permission, and neither should shipping an app. Being big gives no one the
   standing to decide, for everyone, which software deserves to exist.
3. **The apps users need should be installable.** Many apps only ship through
   the vendor's own site, and the vendor has no interest in Linux stores, but
   users need them all the same. The community packages them for users, from
   the vendor's official release.
4. **Choosing is the user's right.** Users can decide for themselves what to
   install. A store's job is to lay out the facts, not to decide for them.
5. **A store's power is for service, not gatekeeping.** A store naturally
   controls recommendation and traffic. On top of the rights of developers and
   users, that power should make things easier and help good apps be seen. It
   must never become a tool for holding others down.

Every rule FlatPark has follows from these, through its
[principles](principles.md).

## How it relates to Flatpak and Flathub

**Flatpak.** FlatPark is an ordinary [Flatpak](https://flatpak.org/) remote:
its apps install, update and run in the sandbox with the stock `flatpak` and
every tool built on it. [rpak](../users/rpak.md), a wrapper around `flatpak`
that accepts every flatpak command, adds what stock Flatpak doesn't have:
parallel downloads of installers, freeing the copies Flatpak keeps, and
running apps from other remotes on a newer runtime.

**Flathub.** FlatPark is a remote like [Flathub](https://flathub.org/), and is
**not affiliated with it**. Its apps run on the freedesktop, GNOME and KDE
runtimes from Flathub, so you add Flathub alongside it. Apps are published as
extra-data, the same way many Flathub apps are: the package pins the official
download, which Flatpak fetches from the vendor at install time. Where FlatPark
differs is that every app is kept on the latest runtime: when a new one comes
out, all the apps on it move together and are tested.

When a developer publishes their own app on Flathub (it is verified there),
FlatPark doesn't package it again, unless the developer asks us to. When
someone else maintains the Flathub package and it is missing a feature, has
fallen behind or has stopped working, FlatPark can offer the app as well, and its
description says how the two differ.

## Who runs it

FlatPark is an independent, community-run project. Its own code is MIT-licensed;
the packaged applications remain their vendors' property and are downloaded
from official sources at install time.
