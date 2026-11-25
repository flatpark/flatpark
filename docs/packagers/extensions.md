---
description: Add-ons for an app already on FlatPark, and shared extensions any app can declare, published as Flatpak extensions with their payload as extra-data.
order: 6
---

# Extensions

An extension adds something to an app that declares an extension point: a driver
for a token hub, a plugin for an editor. Users install it next to the app, and
Flatpak mounts it inside the app's sandbox.

The parent has to be on FlatPark. An extension of something else, such as an SDK
extension whose parent comes from Flathub, isn't supported yet. The exception is
a [shared extension](#shared-extensions), which has no parent at all: any app
that declares it gets it.

## What to know first

- **It runs with all of the parent's permissions.** An extension has none of its
  own: it runs inside the parent's sandbox, and its page says so. Read what the
  parent can reach before you package one.
- **It is not listed as an app.** The site files it under Extensions: it stays
  out of the home grid, All and the category counts, and shows up on its
  parent's page, in the collections that name it, and under Extensions on the
  browse page. `catalog.category` has no effect on where it is listed.
- **The payload is extra-data.** The ref holds only small files, and the program
  comes from upstream at install time, as for an app. This is what keeps an
  extension cheap to host, so nothing compiled or downloaded at build time goes
  into it ([the one rule](basics.md#the-one-rule-extra-data-only)).
- **It follows its parent's runtime.** When the parent moves to a new runtime,
  the parent's PR doesn't pass until the extension's `sdk` moves with it, and a
  compiled payload may need a new upstream release.

## The files

An extension has the same files as an app, without the launcher and the desktop
file: `flatpark.yml`, `<id>.yml`, `apply_extra.sh`, `<id>.metainfo.xml`, an icon
and `resolve-update.sh`, plus whatever the parent reads from it (a driver for
Tessera carries a `driver.toml`). Its id sits below the parent's extension point.

In `flatpark.yml`, `build.extends` names the parent:

```yaml
id: com.example.Hub.Driver.Foo
name: Foo
summary: Foo driver for Hub
source_url: https://github.com/example/foo
build:
  manifest: com.example.Hub.Driver.Foo.yml
  branch: stable
  mode: extra-data
  extends: com.example.Hub
update:
  command: ./resolve-update.sh
```

The manifest names the parent as its runtime, and the SDK of the parent's runtime
version:

```yaml
id: com.example.Hub.Driver.Foo
branch: stable
runtime: com.example.Hub
runtime-version: stable
sdk: org.gnome.Sdk//51
build-extension: true
separate-locales: false
modules:
  - name: foo
    buildsystem: simple
    build-commands:
      - install -Dm755 apply_extra.sh ${FLATPAK_DEST}/bin/apply_extra
      - install -Dm644 com.example.Hub.Driver.Foo.metainfo.xml -t ${FLATPAK_DEST}/share/metainfo
    sources:
      # BEGIN MANAGED EXTRA-DATA
      - type: extra-data
        filename: foo.tar.gz
        only-arches:
          - x86_64
        url: https://github.com/example/foo/releases/download/v1.0.0/foo-x86_64.tar.gz
        sha256: <sha256>
        size: <size>
      # END MANAGED EXTRA-DATA
      - type: file
        path: apply_extra.sh
      - type: file
        path: com.example.Hub.Driver.Foo.metainfo.xml
```

The metainfo is an `addon` component whose `<extends>` names the parent:

```xml
<component type="addon">
  <id>com.example.Hub.Driver.Foo</id>
  <extends>com.example.Hub</extends>
  ...
</component>
```

`apply_extra.sh` runs as for an app, and what it unpacks lands in `extra/` inside
the extension. The extension is mounted at the extension point's `directory`, in a
folder named after the rest of its id when the point has `subdirectories`
(`Foo` for `com.example.Hub.Driver.Foo` under `com.example.Hub.Driver`).

## Test

Build and verify as in [submitting an app](submitting.md), keep the build
installed with `FLATPARK_VERIFY_KEEP=1`, then install the real parent
(`flatpak install flatpark <parent>`) and run the feature the extension adds from
it. An extension that installs and that the parent never loads is not tested.

## Shared extensions

A shared extension belongs to no app. Every app that declares its extension
point mounts it, on whatever runtime the app uses. FlatPark has one,
[flatpark-spawn](../../registry/org.flatpark.Spawn/flatpark.yml), which lets an
app run the host's command-line tools
([running commands on the host](permissions.md#running-commands-on-the-host)).

- **It has no parent.** `build.shared: true` takes the place of `build.extends`,
  and the two exclude each other. Its page is filed under Extensions, lists the
  apps that use it, and shows no permissions: it has none of its own and runs
  with those of each app that mounts it.
- **It comes with the apps that use it.** Installing one of them installs it
  too, and `flatpak uninstall --unused` removes it after the last one goes. It
  can be installed on its own, but does nothing outside an app.
- **It builds against a stand-in.** `flatpak-builder` only builds an extension
  against an installed app that declares its extension point, so the extension
  carries a small stand-in manifest for that. The stand-in is never published.
- **It moves on its own.** An app that uses it can change runtime without
  touching it, and it can be rebuilt without rebuilding them. A change that
  breaks the apps using it goes on a new branch (the extension point's
  `version`), not into the existing one.

### Using a shared extension

An app declares it under `add-extensions`, creates the mount point, and
otherwise leaves it to Flatpak:

```yaml
add-extensions:
  org.flatpark.Spawn:
    directory: lib/flatpark-spawn
    version: '1'
modules:
  - name: app
    buildsystem: simple
    build-commands:
      - mkdir -p /app/lib/flatpark-spawn
      # ...
```

- `version` is the extension's branch, and `directory` is where every app
  mounts it; both are fixed by the extension.
- No `no-autodownload`: the extension has to be installed with the app.
- No `autodelete: true` (leave it out, or write `false`). Flatpak would delete
  the extension when this app is uninstalled, under every other app still
  using it.
- The `mkdir` is required. `flatpak-builder` doesn't create an extension
  point's directory, and without it `flatpak run` fails before the app starts
  (`bwrap: Can't create file /app/lib/flatpark-spawn: Read-only file system`),
  whether or not the extension is installed.

flatpark-spawn asks for more than this; its section in
[permissions](permissions.md#running-commands-on-the-host) has the rest.

## For agents

### What the audit checks

`audit-descriptor.mjs` fails an extension when:

- `build.extends` is not in the registry, or it doesn't declare an extension point
  for this id. A longer id needs a point with `subdirectories: true`.
- The manifest has no `build-extension: true`, or its `runtime` isn't the parent.
- The manifest has `finish-args`.
- It has no `extra-data` source, or it has a `git` or `archive` source.
- The version in `sdk` differs from the parent's `runtime-version`.
- `build.arches` names an arch the parent isn't built for.

A manifest with `build-extension: true` also needs `build.extends` or
`build.shared`.

A shared extension (`build.shared: true`) keeps the payload rules above (no
`finish-args`, extra-data only), and its stand-in,
`registry/<id>/<id>.BuildParent.yml`, takes the parent's place. The audit fails
it when:

- `build.extends` is also set, or `build.shared` is something other than
  `true` or `false`;
- the stand-in is missing, its `app-id` isn't `<id>.BuildParent`, or a registry
  entry has that id (it would be published);
- the manifest's `runtime` isn't the stand-in, or its `runtime-version` isn't the
  stand-in's branch (`master` unless the stand-in sets `branch:`);
- the stand-in declares no extension point named `<id>`, declares it with a
  `version` other than the extension's branch or with no `directory`, or doesn't
  `mkdir -p /app/<directory>`;
- the stand-in names no `runtime` and `runtime-version`, or the version in the
  manifest's `sdk` differs from it.

`build.arches` isn't checked against anything: the stand-in is built for every
arch the extension is.

An app that declares a shared extension is checked by the rules of that
extension; for flatpark-spawn, see
[permissions](permissions.md#what-the-audit-checks-for-flatpark-spawn).

### How it builds

`flatpak-builder` needs the parent installed, and looks for it on Flathub.
`build-app.sh` runs `install-parent-skeleton.sh` first, which installs a stand-in
made from the parent's registry manifest: its metadata and the extension point's
folders. The real parent would fetch all of its extra-data on every build, and
would describe what is published instead of the commit being built. The stand-in
is never published, and it is in the user installation only while the build
runs: flatpak-builder looks for the parent there, and left behind it would
shadow a real parent installed with `--system`.

When the real parent is already in the user installation, the build uses it and
installs no stand-in. For a PR that moves the parent's runtime, that build
follows the published parent and its old runtime: uninstall the parent from the
user installation first, or rely on the PR's CI build, which always uses the
stand-in.

`check-apply-extra.sh` runs `apply_extra.sh` on the parent's runtime, and a
`.flatpakref` to an extension says `IsRuntime=true`.

### How a shared extension builds

`build-app.sh` runs `install-parent-skeleton.sh --manifest
registry/<id>/<id>.BuildParent.yml`, which makes the same kind of stand-in from
that manifest instead of from a parent's: its metadata, the extension point's
folder, a stub command, on the stand-in's branch. It is exported to a throwaway
repository, installed into the user installation for the build and removed
when the build ends; it never reaches the published repository, and
`ostree refs` on a build shows only `runtime/<id>/<arch>/<branch>`.

The built extension's metadata names the stand-in:

```ini
[ExtensionOf]
ref=app/org.flatpark.Spawn.BuildParent/x86_64/master
runtime=org.freedesktop.Platform/x86_64/26.08
```

Mounting ignores both: Flatpak matches an app's extension point by name and
`version`, whatever the app's runtime. The `runtime=` line is what counts.
`apply_extra` runs on it (an extension's metadata has no runtime of its own),
and installing the extension installs that runtime with it, so it is the
stand-in's `runtime`, and `check-apply-extra.sh` uses the same one. An
extension has exactly one such runtime: a user whose only app using it is on
GNOME also gets the freedesktop runtime. Keep it on the freedesktop runtime most
apps here use, and move it by editing the stand-in; the PR then runs the
unpack check again.

Nothing about the apps that use it rebuilds it: `changed-apps.sh` and
`extensions_of` list only `build.extends`, and the stand-in is one of the
extension's own files, so a change to it rebuilds the extension like any
other. A delisted shared extension is dropped by `prune-and-reclaim.sh` like
any other extension, since its `[ExtensionOf]` names the stand-in, which is
never in the registry.

### When the parent changes

(Not for a shared extension, which has none.)

`changed-apps.sh` lists an app's extensions when its `runtime`, `runtime-version`
or `sdk` changes, and when it leaves the registry. The PR then audits and rebuilds
them, so an extension left on the old runtime, or without a parent, fails there.
Move the extensions in the same PR ([batch changes](../reviewers/batch-changes.md)).

A delisted extension has no app ref. `prune-and-reclaim.sh` finds it by the
`[ExtensionOf]` group of its metadata, which names its parent app, and drops the
ref, unless the parent is listed and builds that extension itself
(`bundle: true`).
