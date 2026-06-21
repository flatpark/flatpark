---
title: Publishing guide
description: How to add an app to FlatPark — the descriptor, manifest, and auto-update resolver.
group: Docs
order: 1
---

Any app with a public download is welcome — FlatPark does not host builds. As
long as the app ships an official installer or prebuilt archive at a stable,
public release URL (extra-data style), it can be added here. FlatPark fetches it
at build, pins it, and signs the result.

## Add an app

Create one directory under `registry/` named exactly for the app id:

```text
registry/com.example.App/
  flatpark.yml             # the descriptor (below)
  com.example.App.yml      # the Flatpak manifest
  com.example.App.metainfo.xml
  com.example.App.svg
  resolve-update.sh        # optional: upstream update resolver
```

Then validate and build locally:

```sh
node scripts/read-descriptor.mjs registry/com.example.App/flatpark.yml
./scripts/publish.sh --verify com.example.App
```

### Test without polluting your everyday Flatpak

`publish.sh --verify` adds a local `file://` remote named `flatpark` to your
**`--user`** installation and installs the app there. The scratch repo
(`out/repo`) is rebuilt on every run, so its commits drift from whatever you
have installed — and if you _also_ run the real FlatPark remote in that same
installation, `flatpak update` eventually fails with `Update is older than
current version` and leaves orphaned refs. Keep test builds in a separate,
throwaway installation so they never touch your normal Flatpak state:

```sh
# one-time: create an isolated installation named "test"
sudo install -d /etc/flatpak/installations.d
printf '[Installation "test"]\nPath=%s/.local/share/flatpak-test\nDisplayName=FlatPark test\n' \
  "$HOME" | sudo tee /etc/flatpak/installations.d/test.conf >/dev/null

# install the freshly built app into it, then wipe it when done
flatpak --installation=test remote-add --no-gpg-verify flatpark "file://$PWD/out/repo"
flatpak --installation=test install flatpark com.example.App
flatpak --installation=test uninstall --all
```

Open a PR. `pr-checks` validates the descriptor, runs the test suite, checks for
dead links, and (for same-repo PRs) builds the app. On merge, `publish` builds
and publishes it.

## `flatpark.yml` schema

```yaml
id: com.example.App           # required — must match the directory name
name: Example App             # required
summary: One-line description # required
website: https://example.com/ # optional
source_url: https://github.com/you/packaging  # optional
build:
  manifest: com.example.App.yml  # required — relative to this directory
  branch: stable              # optional (default: stable)
  mode: extra-data            # packaging mode (internal label)
catalog:                      # optional — drives the catalog page
  category: Productivity
  tags:
    - Example
    - Demo
update:                       # optional — enables auto pin-bump PRs
  command: ./resolve-update.sh
policy:                       # optional — informational
  proprietary: true
  extra_data_first: true
  dangerous_permissions: []
```

Only `id`, `name`, `summary`, and `build.manifest` are required.

## Auto-updating (optional)

Version checking is **always a script** — there are no declarative checker types
to learn. Point `update.command` at a `resolve-update.sh` that figures out the
current release however it likes (a JSON/HTML endpoint, the GitHub API, a fixed
URL, whatever) and prints this JSON to stdout (logs go to stderr):

```json
{
  "version": "1.2.3",
  "releaseDate": "2026-06-19",
  "sources": [
    { "filename": "installer.sh", "url": "https://example.com/installer-1.2.3.sh" }
  ]
}
```

The script does **no hashing** — it just resolves the version and the real
download URL(s). FlatPark downloads each source, computes `sha256`/`size`, and
rewrites the manifest's managed block (mark it with these comments so FlatPark
knows what to rewrite):

```yaml
# BEGIN MANAGED EXTRA-DATA
- type: extra-data
  filename: installer.sh
  only-arches:
    - x86_64
  url: https://example.com/installer-1.2.3.sh
  sha256: <computed by FlatPark>
  size: <computed by FlatPark>
# END MANAGED EXTRA-DATA
```

**Where the version lives:** in the AppStream metainfo `<releases>`, not in
extra-data (Flatpak has no version field there). The latest `<release version>`
is the comparison anchor: each day `update-check` runs your resolver, and only
when its `version` differs from the metainfo does it download, re-pin, prepend a
new `<release>`, and open a PR. A maintainer merges it, which rebuilds and
republishes just that app.

### Resolver templates

GitHub releases (pick the right asset):

```sh
#!/usr/bin/env bash
set -euo pipefail
repo="owner/name"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
url="$(jq -r '.assets[]|select(.name|test("x86_64.*\\.AppImage$")).browser_download_url' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v,releaseDate:$d,sources:[{filename:"app.AppImage",url:$u}]}'
```

A vendor JSON endpoint (version in one field, URL in another):

```sh
#!/usr/bin/env bash
set -euo pipefail
meta="$(curl -fsSL https://vendor.example/latest.json)"
version="$(jq -r '.version' <<<"$meta")"
url="$(jq -r '.assets[]|select(.name|test("linux-x86_64\\.deb$")).url' <<<"$meta")"
date="$(jq -r '.published_at // ""' <<<"$meta" | cut -c1-10)"
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v,releaseDate:$d,sources:[{filename:"app.deb",url:$u}]}'
```

A fixed URL that simply embeds the version:

```sh
#!/usr/bin/env bash
set -euo pipefail
version="$(curl -fsSL https://vendor.example/latest.txt)"
jq -n --arg v "$version" \
  '{version:$v,sources:[{filename:"app.bin",url:("https://vendor.example/app-"+$v+".bin")}]}'
```

## Sandbox & permissions

Prefer the tightest `finish-args` that still work. Avoid `--filesystem=home` and
other broad grants; FlatPark surfaces permissions on each app's detail page, and
broad grants will be questioned in review.
