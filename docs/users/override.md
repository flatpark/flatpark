---
description: "Change what an app may access with flatpak override: what it is, how to check it, and the cases that come up: other disks, SSH keys, devices, the network, scaling, host commands."
order: 4
---

# flatpak override

Every Flatpak app runs in a sandbox, and its package says what it may reach:
which folders, devices, network, desktop services. Each FlatPark app asks for
as little as its main job needs, and its page lists every permission with a
plain note on what it allows.

`flatpak override` is how **you** change that list for an app, in either
direction: give it a folder it doesn't have, or take away something the package
grants. Your changes are kept separately from the package, so they survive
updates, and you can undo them at any time.

Answers you give in the desktop's own permission dialogs (allow a screenshot,
use the camera, "open with") are kept somewhere else: see the
[permission store](permission-store.md).

## Checking

```sh
flatpak info --show-permissions <app-id>      # what the app runs with now, all changes included
flatpak override --user --show <app-id>       # only what you changed
flatpak override --user --reset <app-id>      # undo all of your changes
```

A permission you **removed** doesn't show up in the first command's output at
all; the second shows it. Tools like Flatseal change the same overrides, so
both commands show what you did there too.

`--user` changes affect only you. Without it (and with `sudo`) a change applies
to everyone on the computer; yours are applied on top.

## Common cases

**Turning on an optional permission.** Some apps can do more with a broader
permission, which is off by default. The app's page gives the exact command:

```sh
flatpak override --user --filesystem=~/.ssh:ro org.electerm.Electerm
```

Think about what a grant opens up before running it. `--filesystem=home` lets
the app read and change everything in your home folder.

**A library on another disk.** Files you open through the file chooser always
work. A folder the app should see by itself, on a second disk or a USB drive,
needs a grant; add `:ro` when the app only reads:

```sh
flatpak override --user --filesystem=/mnt/music com.foobar2000.Foobar2000
flatpak override --user --filesystem=/mnt/data:ro com.calibre_ebook.calibre
flatpak override --user --filesystem=/run/media com.foobar2000.Foobar2000     # USB drives
```

**SSH keys.** `--socket=ssh-auth` lets the app use your SSH agent without seeing
the keys; prefer it when the app supports an agent. `--filesystem=~/.ssh:ro`
lets it read the key files.

**Serial ports, security keys, cameras.** Flatpak can't grant a single device;
it is `--device=all` or nothing, so grant it only to apps that need it:

```sh
flatpak override --user --device=all io.github.binaricat.Netcatty
```

**Keeping an app offline.** `--unshare=network` cuts it off; update checks,
sign-in and online features stop. `--share=network` undoes it.

```sh
flatpak override --user --unshare=network com.snipaste.Snipaste
```

**Size and drawing problems.** The app's page names the setting that fixes it,
usually an environment variable. `--unset-env=NAME` removes one.

```sh
flatpak override --user --env=GDK_SCALE=2 com.falconpdf.app
flatpak override --user --env=UI_SCALE=2 com.schwab.thinkorswim
flatpak override --user --env=WEBKIT_DISABLE_COMPOSITING_MODE=1 dev.aninsomniacy.rayburst
```

**Apps that can run commands on your system.** A few packages need this for one
feature, and their page shows **Reduced isolation** and why. Take it away, and
only that feature stops (for Enpass, the browser extension):

```sh
flatpak override --user --no-talk-name=org.freedesktop.Flatpak io.enpass.Enpass
```

**The app forgets its settings.** If you turned off one of its folders (in
Flatseal, say), Flatpak puts an empty temporary folder in its place and the app
loses what it writes there. Check `--show`, and remove that entry or `--reset`.
If you changed nothing, it is a packaging bug:
[report it](troubleshooting.md#reporting-a-problem). Until it's fixed,
`flatpak override --user --persist=.something <app-id>` keeps a hidden
`~/.something` folder inside the app's own data.

**Saving a file fails with "Device or resource busy".** The app was granted that
one file rather than its folder. Grant the folder instead; the details are
below.

## For agents

### Where overrides live, and in what order they apply

| Layer | Where |
|---|---|
| The package's `finish-args` | The app's metadata: `flatpak info --show-metadata <app-id>` |
| System overrides, every app | `/var/lib/flatpak/overrides/global` |
| System overrides, one app | `/var/lib/flatpak/overrides/<app-id>` |
| User overrides, every app | `~/.local/share/flatpak/overrides/global` |
| User overrides, one app | `~/.local/share/flatpak/overrides/<app-id>` |
| `flatpak run` flags | That run only |

Later layers win. The files are keyfiles (`[Context]`, `[Environment]`,
`[Session Bus Policy]`); removals are written as `!path` or `!name`.

**Global overrides are the classic surprise.** `flatpak override --user` without
an app id changes *every* app. When an app has a permission that neither its
page nor its own override explains, read the `global` files.

### Testing a grant without changing the user's setup

Use `flatpak run` flags; they last one run and write no file:

```sh
flatpak run --command=sh --filesystem="${dir}:ro" <app-id> -c "touch '$dir/x' || echo read-only"
flatpak kill <app-id>
```

- Quote `"${dir}:ro"`. In zsh, `$dir:ro` applies the `:r` modifier to the
  variable and silently grants a different path.
- `flatpak run --command=sh` doesn't start the app, and the shell sees the same
  sandbox it would.
- If a persistent override is unavoidable, record `--show` first and restore
  exactly that afterwards; never `--reset` an app the user configured.

### A single granted file and EBUSY

A single-file grant (`--filesystem=~/.app.json`) is a bind mount on that file.
Apps that save atomically write a temporary file and `rename(2)` it over the
original, and a mount point can't be replaced, so the rename fails with `EBUSY`.
Grant the folder instead. For a file directly in home, grant `home` and remove
the file's own grant, so it is reached through the home mount:

```sh
flatpak override --user --filesystem=home --nofilesystem=~/.app.json <app-id>
```

Packages should never grant a file the app rewrites; see
[permissions for packagers](../packagers/permissions.md#single-files).

### When grants overlap

Checked with Flatpak 1.18.4:

| What the app has | Result |
|---|---|
| `home:ro` and `xdg-documents` | Documents writable, the rest of home read-only. The more specific path wins inside its own subtree. |
| `~/Projects` and `~/Projects/secret:ro` | `secret` read-only, the rest writable. |
| The same path twice with different modes | The later one wins; a user override replaces the package's mode. |
| Only `~/Projects/app` | `~/Projects` exists in the sandbox with just `app` in it. Files written directly into `~/Projects` go to a throwaway directory. |
| A folder, and a folder inside it removed | The inner folder is an empty tmpfs; writes there are lost on exit. |
| A folder, and a file inside it removed | The file stays reachable through the folder (this is what fixes EBUSY). |
| `xdg-documents`, and `home` removed | Documents still available; removing a broad grant leaves narrower ones. |
| A grant on a symlink | Its target is reachable. |
| `--persist=.x` and `home` | `--persist` is ignored. |
