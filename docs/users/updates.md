---
description: How new versions reach you, and why every app moves to a new runtime at the same time.
order: 3
---

# Updates

Run `flatpak update` as you would for any Flatpak app, or let your software
centre do it:

```sh
flatpak --user update
```

## How new versions arrive

FlatPark watches each app's official releases. Many developers notify FlatPark
the moment they publish, and the rest are checked twice a day. A new version is
re-pinned, checked to install, and published, usually within minutes to hours
of the release; no one has to approve each one.

What you download on update is the developer's own new release: Flatpak fetches
it from their servers and unpacks it on your computer, as it did on install.

## Following new apps and releases

The site publishes two Atom feeds; add either to your feed reader:

- [flatpark.org/feed.xml](https://flatpark.org/feed.xml): apps as they are
  newly listed, newest first.
- [flatpark.org/updates.xml](https://flatpark.org/updates.xml): new versions
  of the listed apps, each titled with the app's name and version.

Both are rebuilt with the site on every publish. A release appears in
`updates.xml` from the date in the app's own release list, which may be a
little before FlatPark has re-pinned it; `flatpak update` is the source of
truth for what you can install now.

## Runtimes move together

Every app uses the current version of its runtime (the shared base that
Flatpak apps are built on). When a new version of the runtime comes out, the
whole catalog moves to it at once and is tested together, so you never keep an
old runtime on disk for one app that stayed behind. After such a move,
`flatpak update` downloads the new runtime once, and
`flatpak uninstall --unused` removes the old one ([cleaning up](cleanup.md)).
Apps from other remotes may stay behind on an old runtime; rpak can
[run them on the new one](rpak.md#running-an-app-on-a-newer-runtime-experimental).
