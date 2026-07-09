---
title: User guide
description: Installing, updating, uninstalling, and understanding FlatPark apps.
group: Docs
order: 2
---

## Installing an app

First add the FlatPark remote (once), then install any app:

```sh
flatpak --user remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak --user install flatpark <app-id>
```

The [setup page](/setup/) has the full first-time walkthrough, including the
runtime remote.

## User vs system install

`--user` installs into your home directory and needs no admin rights. Drop
`--user` from both commands for a system-wide install (requires root). You can
use either; `--user` is the simplest if you are not sure.

## Updates and runtimes

A daily check watches each app's upstream release channel and opens a pull
request to re-pin new versions, so a normal `flatpak update` keeps everything
current.

Runtimes move in step. Every app targets the current major of its runtime — the
catalog is never split across, say, GNOME 49 and 50 — so you don't end up
carrying an old major on disk just for one straggler app. When a new major lands,
the whole catalog is rebuilt and tested against it together:

```sh
flatpak --user update
```

## Reading an app's permissions

Every app page lists the exact sandbox permissions it requests, with a
plain-language risk label. Check these before installing — see
[Trust & safety](/trust/) for what the model guarantees.

## Granting an optional permission

Packages ship with the tightest sandbox that still lets the app work, so some
optional capabilities are switched off on purpose. When an app has one, its page
spells out the exact command to enable it, and you decide whether to run it:

```sh
flatpak override --user --filesystem=~/.ssh:ro org.electerm.Electerm
```

Review what a grant opens up before applying it — `--filesystem=home`, for
instance, exposes your whole home directory to the app. To see what you have
changed, or to undo it:

```sh
flatpak override --user --show org.electerm.Electerm
flatpak override --user --reset org.electerm.Electerm
```

## Uninstalling

```sh
flatpak --user uninstall <app-id>
```

To also remove unused runtimes afterwards:

```sh
flatpak --user uninstall --unused
```

## Troubleshooting

- **App not found:** make sure the remote was added (`flatpak remotes`) and the
  app id is spelled exactly as shown on its page.
- **Signature/GPG errors:** re-add the remote with the command above; it pins the
  signing key.
- **Won't launch:** run it from a terminal (`flatpak run <app-id>`) to see the
  error output.
