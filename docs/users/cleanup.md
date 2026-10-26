---
description: Uninstall apps and their data, remove unused runtimes, and reclaim the space Flatpak keeps for downloaded installers.
order: 6
---

# Cleaning up

## Uninstalling an app

```sh
flatpak --user uninstall <app-id>                 # keeps its settings and data
flatpak --user uninstall --delete-data <app-id>   # removes those too
```

Without `--delete-data`, the app's settings stay in `~/.var/app/<app-id>/`, so
reinstalling it later picks up where you left off.

Uninstalling doesn't touch files the app wrote **outside** its sandbox: into
folders it was allowed to use (Documents, Pictures, a `~/.app-name` folder of
its own). The permissions list on the app's page shows which folders those are.
Changes you made with `flatpak override` stay too; remove them with
`flatpak override --user --reset <app-id>`. So do the answers you gave in its
permission dialogs; `flatpak permission-reset <app-id>` clears them
([permission store](permission-store.md)).

## Removing unused runtimes

Runtimes are shared, so they stay when the last app using them goes, and an old
one stays after the catalog moves to a new version. Remove what nothing uses:

```sh
flatpak --user uninstall --unused
```

## Removing FlatPark

Uninstall its apps first, then:

```sh
flatpak --user remote-delete flatpark
```

Use the same commands without `--user` for a system-wide setup.

## Reclaiming space from downloaded installers

When Flatpak installs an app like FlatPark's, which downloads the developer's
own file at install time, it unpacks that file and **also keeps the original
download** in its repository. Every update adds the new one. For large apps that
adds up: the copy is as big as the app's installer, and it is only used again if
you reinstall that exact version.

To see how much space these copies take:

```sh
find ~/.local/share/flatpak/repo/objects -name '*.commitmeta' -size +100k \
  -exec grep -laF xa.extra-data {} + | xargs -r du -ch | tail -1
```

To remove them, while no Flatpak install or update is running:

```sh
find ~/.local/share/flatpak/repo/objects -name '*.commitmeta' -size +100k \
  -exec grep -laF xa.extra-data {} + | xargs -r rm -f
```

The trade-off: Flatpak stores the download in the same file as the signature of
that app version, so the signature goes too. It is only checked when a version
is downloaded, so running, updating and `flatpak repair` are unaffected, and
the next update brings a new, signed version. Since every update stores a new
copy, this is worth repeating now and then. For a system-wide setup, the
repository is `/var/lib/flatpak/repo` and the commands need `sudo`.

## For agents

### How the cache works

An extra-data download is stored in the commit's detached metadata
(`objects/<xx>/<rest>.commitmeta`) under the key `xa.extra-data`, as an array of
`(filename, bytes)`. The same GVariant holds the commit's GPG signatures
(`ostree.gpgsigs`), and no Flatpak or OSTree command removes one key without
the other, so deleting the cache means deleting the whole `.commitmeta`. A
signature-only `.commitmeta` is a few hundred bytes, hence the `-size +100k`
pre-filter; the `grep` confirms the key before anything is removed.

Inspect one before deleting:

```sh
ostree --repo="$HOME/.local/share/flatpak/repo" show \
  --print-detached-metadata-key=xa.extra-data <commit> | head -c 200
```

where `<commit>` is the object's directory name followed by its file name
without `.commitmeta`. The commit's ref is found by matching it against
`refs/heads/`.

### Doing it safely

- Check no Flatpak transaction holds the repository: `flock -n <repo>/.lock true`
  fails while one does.
- Report what would go first (sizes and refs), then delete only after the user
  agrees. Moving the files to a backup directory instead of deleting them makes
  it reversible: put them back in the same place.
- `ostree --repo=<repo> prune --refs-only` afterwards reclaims objects no ref
  reaches any more; run it with `--no-prune` first to see what it would do.
- Never touch the system repository without the user asking for it; it needs
  root and affects every user on the machine.
