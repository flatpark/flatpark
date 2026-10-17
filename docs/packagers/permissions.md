---
description: Which sandbox permissions a package grants, which it leaves to the user, and what has to be declared.
order: 5
---

# Permissions

A package grants the **smallest set of permissions that lets the app's main
feature work**, with a comment on each. Everything the app can do beyond that is
left off and documented as a `flatpak override` command in the app's
description, so each user decides. Permissions show on every app's page.

- **Files:** grant the directory the app works in by default (`xdg-pictures`
  for a screenshot tool, `xdg-music` for a player), not `home`. Files opened
  through the file chooser need no grant at all.
- **The app's own `~/.something`:** Flatpak only redirects the XDG directories.
  An app that writes a dotdir in your home loses it on every restart unless the
  package grants it.
- **High-risk permissions** (running commands outside the sandbox, devices,
  the whole home directory) are declared in `flatpark.yml`, argued for in the
  PR and reviewed by a maintainer. They are granted when the app's main feature
  needs them, or when leaving them out would take more overrides than a user
  can be expected to manage. The app page marks them with a warning.
- **The developer decides for their own app.** When upstream says how they want
  the package to behave, we follow it, and declare what it needs.

## For agents

### Optional capabilities as overrides

Put them in the metainfo description, where the app page shows them, with a line
that undoes them:

```xml
<p>A few optional capabilities are not granted by default; enable the ones you
   need with "flatpak override":</p>
<ul>
  <li>Reuse your host SSH keys: <code>flatpak override --user --filesystem=~/.ssh:ro org.electerm.Electerm</code></li>
  <li>Serial ports: <code>flatpak override --user --device=all org.electerm.Electerm</code></li>
  <li>Undo all of these: <code>flatpak override --user --reset org.electerm.Electerm</code></li>
</ul>
```

Adapted from [Electerm](../../registry/org.electerm.Electerm/org.electerm.Electerm.metainfo.xml).
That other apps on Flathub grant `home` makes a broad grant acceptable, not
necessary; ship the narrow one.

### Home-directory dotdirs

Inside the sandbox `$HOME` is still `/home/<user>`, an almost empty overlay;
only `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_CACHE_HOME` point into
`~/.var/app/<id>/`. An app that writes `$HOME/.app` (Java's `user.home`, Node's
`os.homedir()`, Go's `UserHomeDir`) writes into a tmpfs that disappears on exit.
Check with `flatpak run --command=sh <id> -c 'echo $HOME; ls -la $HOME'`, and
after a restart.

- **The app's own directory:** `--filesystem=~/.app:create`. It lives in the
  real home, so it is shared with a native install and the user can find it.
  Or `--persist=.app`, which keeps it under `~/.var/app/<id>/` instead.
  `--persist` is ignored when `home` or `host` is also granted.
- **Another tool's directory** the app reads (an editor reading CLI configs):
  grant it **without** `:create`. With it, every tool the user never installed
  gets an empty directory in their home, and apps that take "the directory
  exists" to mean "the tool is installed" get it wrong.
- **A lock file in that directory:** apps that keep their single-instance lock
  there start a second copy when it is lost, which then fails on a port the
  first one holds.

This is the most common severe bug in our history: four apps lost settings or
data on every restart for this reason before it was understood.

### Single files

Don't grant a single file (`--filesystem=~/.app.json`) that the app rewrites by
saving a temporary file and renaming it over the original. The grant is a bind
mount on that file, and the rename fails with `EBUSY`. Grant the directory
instead.

### Declaring high-risk permissions

List them under `policy.dangerous_permissions` in `flatpark.yml` and explain each
in the PR. Reaching outside the sandbox (`--filesystem=host`, `--filesystem=/`,
`--talk-name=org.freedesktop.Flatpak`) is granted only when it is declared,
argued in the PR, needed by the app's feature, and reviewed by a maintainer.

[Enpass](../../registry/io.enpass.Enpass/io.enpass.Enpass.yml) is the example.
It checks which browser is behind its extension's local connection by running
`lsof` and reading `/proc`, which can't work in the sandbox. Instead of
patching Enpass, the package puts small `lsof`, `readlink` and `cat` scripts on
`PATH` that run the real commands on the host through `flatpak-spawn --host`.
Nothing is injected into Enpass, but the package needs
`--talk-name=org.freedesktop.Flatpak`, which lets the app run any host command:
it declares that, and its page says so.

### Declaring changes to how the app runs

Anything a package does beyond starting the vendor's build goes under
`packaging:` in `flatpark.yml`, one entry per change, with a sentence in English
and Chinese. The site shows the resulting
[packaging level](../project/trust.md#packaging-changes).

| Kind | When | Level | Allowed for |
|---|---|---|---|
| `support-files` | Libraries or tools added next to the app (prebuilt stacks, a second download) | Adapted | All; derived from the manifest, not declared |
| `seeded-config` | Settings written before first launch, e.g. turning off an updater that can't work | Adapted | All |
| `injected-code` | An `LD_PRELOAD` library or other code in the app's process | Modified | Closed source only |
| `file-change` | Files in the vendor's build added, removed or changed | Modified | Closed source only |
| `runtime-install` | The vendor's installer runs at first launch with parts stood in for or its result changed (running it unmodified is not a change) | Modified | Closed source only |
| `host-command` | The app can run commands on the host (`flatpak-spawn --host`) | Reduced isolation | All, declared |
| `sandbox-off` | The app's own sandbox is turned off (`--no-sandbox`, `WEBKIT_DISABLE_SANDBOX`) | Reduced isolation | All, declared |

`audit-descriptor.mjs` fails a package whose scripts show one of these without
the matching entry. A wrapper that only sets environment variables or flags is
Unmodified and declares nothing. Leaving out parts of the vendor package that
can't work in Flatpak (a setuid `chrome-sandbox`, a `pkexec` updater, a
file-manager extension) is not a change.

An open-source app that can't work without injected code or changed files is not
listed; the fix belongs upstream.

### When the developer has asked

If upstream states what they want — more permissions, fewer, a different
default — apply it in its own PR, declare what needs declaring, and link their
request. The narrow default above is for when they haven't said.
