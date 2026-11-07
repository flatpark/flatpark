---
description: Add-ons for an app already on FlatPark, published as Flatpak extensions with their payload as extra-data.
order: 6
---

# Extensions

An extension adds something to an app that declares an extension point: a driver
for a token hub, a plugin for an editor. Users install it next to the app, and
Flatpak mounts it inside the app's sandbox.

The parent has to be on FlatPark. An extension of something else, such as an SDK
extension whose parent comes from Flathub, isn't supported yet.

## What to know first

- **It runs with all of the parent's permissions.** An extension has none of its
  own: it runs inside the parent's sandbox, and its page says so. Read what the
  parent can reach before you package one.
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

## For agents

### What the audit checks

`audit-descriptor.mjs` fails an extension when:

- `build.extends` is not in the registry, or it doesn't declare an extension point
  for this id. A longer id needs a point with `subdirectories: true`.
- The manifest has no `build-extension: true`, or its `runtime` isn't the parent.
- The manifest has `finish-args`.
- It has no `extra-data` source, or it has a `git` or `archive` source.
- The version in `sdk` differs from the parent's `runtime-version`.

A manifest with `build-extension: true` also needs `build.extends`.

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

### When the parent changes

`changed-apps.sh` lists an app's extensions when its `runtime`, `runtime-version`
or `sdk` changes, and when it leaves the registry. The PR then audits and rebuilds
them, so an extension left on the old runtime, or without a parent, fails there.
Move the extensions in the same PR ([batch changes](../reviewers/batch-changes.md)).

A delisted extension has no app ref. `prune-and-reclaim.sh` finds it by the
`[ExtensionOf]` group of its metadata, which names its parent app, and drops the
ref, unless the parent is listed and builds that extension itself
(`bundle: true`).
