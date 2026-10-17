---
description: What a FlatPark package is made of, what runs when, and why the app itself is never in it.
order: 2
---

# What a package is

A FlatPark package is one directory under [`registry/`](../../registry/README.md),
named exactly for the app's Flatpak id. It holds no copy of the app. Its manifest
names the vendor's own download by URL, checksum and size, and Flatpak fetches
that download on the user's machine when the app is installed. What FlatPark
builds, signs and hosts is only what goes around it: a launcher, a desktop entry,
an icon, the AppStream data and a script that unpacks the download.

## The files

| File | What it is for |
|---|---|
| `flatpark.yml` | The descriptor: name, summary, category, which manifest to build, how to check for updates, what the package changes. CI and the site read it. |
| `<id>.yml` | The Flatpak manifest: runtime, sandbox permissions, and the pinned download. |
| `apply_extra.sh` | Unpacks the download on the user's machine, at install time. |
| `<name>-wrapper` | The launcher. Sets what the app needs and starts the vendor's binary. |
| `<id>.desktop`, `<id>.metainfo.xml`, `<id>.png` or `<id>.svg` | What the desktop and software centres show. The metainfo also records the current version. |
| `resolve-update.sh` | Finds upstream's latest release and its download URL. |

Some packages carry more: a `fonts.conf`, a second launcher for a CLI, a small
shim. Each one is listed in the manifest and explained in a comment there.

## What runs when

1. **Build** (CI, on merge). `flatpak-builder` installs the launcher, the unpack
   script and the desktop files into the app. The vendor's download is not
   fetched; the manifest only records where it is.
2. **Install** (the user's machine). Flatpak downloads the vendor's file, checks
   its size and SHA-256, and runs `apply_extra.sh` offline to unpack it into
   `/app/extra`.
3. **Launch.** The desktop entry runs the wrapper, which starts the vendor's
   binary from `/app/extra`.
4. **Update.** Twice a day, and within minutes for apps whose upstream sends us
   a release notice, `resolve-update.sh` is asked for the latest version. When
   it changed, CI re-pins the download, adds a release to the metainfo and
   publishes. The user's next `flatpak update` downloads the new file and runs
   `apply_extra.sh` again.

## The one rule: extra-data only

The app always comes from the vendor's own URL, fetched at install time (Flatpak
calls this *extra-data*). FlatPark doesn't build apps from source and doesn't
host their files. Three reasons:

- **You run what the vendor shipped.** A reviewer checks a pin and an unpack
  script, not a build. Users can compare the checksum with the vendor's.
- **Closed-source apps can be listed.** Most licences allow downloading from the
  vendor but not redistributing; we never redistribute.
- **It stays cheap and fast.** A package on FlatPark's storage is a few
  megabytes of scaffolding instead of the whole app, and an update is a re-pin,
  not a rebuild, so it ships minutes after upstream's release. CI downloads the
  new file once to record its checksum and size; users download it from the
  vendor, never from FlatPark.

The one thing a package may build in is a shared support library from
[`flatpark/prebuilt`](prebuilt.md). Everything else
the app needs and the runtime lacks is a second extra-data download.

## For agents

### `flatpark.yml`

```yaml
id: com.example.App           # required: the directory name
name: Example App             # required
summary: One-line description # required
website: https://example.com/
source_url: https://github.com/example/app   # upstream source, if open
build:
  manifest: com.example.App.yml  # required, relative to this directory
  branch: stable              # default: stable
  mode: extra-data
  arches: [x86_64, aarch64]   # default: [x86_64]
catalog:
  category: Productivity
  tags: [Example, Demo]
  upstream_approved: true     # only with a row in upstream-approvals.md
update:
  command: ./resolve-update.sh
policy:
  proprietary: true           # honest; drives the licence shown on the site
  dangerous_permissions: []   # high-risk finish-args, each argued in the PR
packaging:                    # anything beyond a plain launch
  - kind: seeded-config
    detail:
      en: "One sentence a user can read."
      zh-Hans: "同一句话的中文。"
```

- `build.arches`: list `aarch64` only when upstream publishes an arm build and
  the manifest pins it. Each extra-data source then carries its own
  `only-arches`. The simplest shape gives both payloads the same `filename`, so
  `apply_extra.sh` unpacks one name on either arch.
- `catalog.upstream_approved` is the blue shield. CI fails it without a matching
  row in [upstream approvals](../reference/upstream-approvals.md).
- `packaging` declares what the package changes around the vendor's build;
  the kinds and levels are in [permissions](permissions.md#declaring-changes-to-how-the-app-runs).

### The manifest

A typical manifest, trimmed (the full file is
[`dev.tabularis.Tabularis`](../../registry/dev.tabularis.Tabularis/dev.tabularis.Tabularis.yml),
a Tauri app whose upstream approved the listing and pushes its releases to us):

```yaml
id: dev.tabularis.Tabularis
runtime: org.gnome.Platform
runtime-version: "51"
sdk: org.gnome.Sdk
command: tabularis
separate-locales: false
build-options:
  no-debuginfo: true
finish-args:
  # why each grant is needed, one comment per group
  - --share=ipc
  - --share=network
  - --socket=wayland
  - --socket=fallback-x11
  - --device=dri
  - --talk-name=org.freedesktop.secrets
modules:
  - name: tabularis
    buildsystem: simple
    build-commands:
      - install -Dm755 apply_extra.sh /app/bin/apply_extra
      - install -Dm755 tabularis-wrapper /app/bin/tabularis
      - install -Dm644 dev.tabularis.Tabularis.desktop /app/share/applications/dev.tabularis.Tabularis.desktop
      - install -Dm644 dev.tabularis.Tabularis.metainfo.xml /app/share/metainfo/dev.tabularis.Tabularis.metainfo.xml
      - install -Dm644 dev.tabularis.Tabularis.png /app/share/icons/hicolor/512x512/apps/dev.tabularis.Tabularis.png
    sources:
      # BEGIN MANAGED EXTRA-DATA
      - type: extra-data
        filename: tabularis.deb
        only-arches: [x86_64]
        url: https://github.com/TabularisDB/tabularis/releases/download/v0.28.0/tabularis_0.28.0_amd64.deb
        sha256: 237649b0…
        size: 20561470
      # END MANAGED EXTRA-DATA
      - type: file
        path: apply_extra.sh
      - type: file
        path: tabularis-wrapper
      # … one `type: file` per packaging file
```

- **Runtime.** Every app is on the current major of its runtime:
  `org.freedesktop.Platform` 26.08, `org.gnome.Platform` 51, or
  `org.kde.Platform` 6.11. Never an older major for one app. Which one to pick
  depends on what the payload brings with it; see [choosing a format](formats/README.md).
- **`apply_extra` must be installed to `/app/bin/apply_extra`.** That path is
  how Flatpak finds it.
- **The managed block** (`# BEGIN MANAGED EXTRA-DATA` … `# END`) is rewritten
  whole by the updater. Anything else inside it is lost on the next update, so
  a fixed second download (a prebuilt tool, a fonts archive) goes *outside* the
  block. Debian packages pinned as extra-data have their own block,
  `# BEGIN MANAGED DEBIAN <suite> <components>`, re-pinned by a separate job.
- **`size` must be right.** Flatpak checks it before the checksum. When you
  change a URL by hand, change `sha256` and `size` together; a wrong size
  builds fine and fails only at install ("Wrong size for extra data").
- **`no-debuginfo: true` alone does not strip.** It drops the debug split; if
  `/app` contains real binaries (not just scripts), add `strip: true` as well,
  or the ref grows instead of shrinking.
- **`finish-args`** are the smallest set that lets the core feature work, with
  a comment on each group. Optional extras are documented as `flatpak override`
  commands in the metainfo, not granted; see [permissions](permissions.md).

### `apply_extra.sh`

This is the part that differs most from an ordinary Flatpak, and the part that
breaks installs when it is wrong. It runs:

- **at install and on every update,** on the user's machine, in `/app/extra`,
  where Flatpak has put each download under its `filename`;
- **offline** — no network at all;
- **inside the runtime, with only the runtime's `/usr` and `/app/extra`
  visible** on a system-wide install. `/app/bin` is not there, so a tool the
  script needs (unsquashfs for an AppImage, for example) has to arrive as
  extra-data too, not be built into the app;
- **as root with every capability dropped** on a system-wide install. A `tar`
  or `bsdtar` that tries to restore the archive's owner fails and aborts the
  unpack. Always pass `--no-same-owner`. A `--user` install runs as the user and
  never shows this, which is why the check below exists. Archives made without
  `fakeroot` record a real uid (1000, 1001…);
  `bsdtar --numeric-owner -tvf <file> | awk '{print $3":"$4}' | sort -u` shows it.

What it must do:

- Check each expected download exists, unpack it, and move the app to a fixed
  path (`/app/extra/<name>`), not a versioned one, so the wrapper works across
  updates.
- Don't hardcode a name upstream can change between releases: a versioned
  directory, or the launcher binary itself. Updates are merged without a
  human, so read the name out of the archive (a `.deb`'s own desktop entry
  `Exec=` is the authority for Electron builds) and fail if it is ambiguous.
  tldraw renamed its launcher in 1.12 and the refreshed pin shipped an app
  nobody could install ([#130](https://github.com/flatpark/flatpark/issues/130)).
- Check the binary it is about to hand to the wrapper exists, and fail with a
  clear message if not. An upstream that changes its archive layout then fails
  the update check instead of shipping a broken app.
- Delete the downloaded archives and staging directories. What is left in
  `/app/extra` stays on the user's disk.
- Nothing that must be *exported* — the desktop entry, icon, metainfo — can come
  from here. Flatpak exports files at build time, before the download exists.
  Ship them as `type: file` sources even if the vendor's archive has its own.

The runtime has `bsdtar` (libarchive: tar in every compression, zip, `.deb`,
`.rpm`, 7z), GNU `tar` and the usual coreutils. It has no `ar`, `dpkg`, `rpm2cpio`
or `unsquashfs`.

Test it the way a system install runs it before opening a PR:

```sh
./scripts/check-apply-extra.sh com.example.App
```

It runs the real pinned download through your `apply_extra.sh` as root without
capabilities, offline. The update job runs the same check on every new upstream
release and holds back a pin that fails it.

### Icon

Name it `<id>.png` or `<id>.svg` in the package directory, even if the manifest
installs it under another name: the site only picks up that name, and
`audit-descriptor.mjs` fails without it. A PNG is at most 512×512 (Flatpak's
validator rejects larger); resize with `ffmpeg` or `rsvg-convert` from the SDK.

### The wrapper

A short `sh` script installed as `/app/bin/<command>`. It sets environment
variables and flags the app needs in the sandbox, then `exec`s the vendor's
binary from `/app/extra`. Keep it to that: anything that writes files, patches
the payload or preloads code changes the packaging level and must be declared.
Say why each line is there in a comment; the next packager reads the wrapper
first.

### The metainfo and the version

Flatpak has no version field for extra-data. **The version lives in the
metainfo**, as the newest `<release version="…" date="…">` entry, and that is
what the updater compares against. A new package starts with one `<release>`
for the version it pins. The description is shown on the app's page, so it is
also where opt-in `flatpak override` commands and any disclosed change go.

The rest of the metainfo:

- **Say it is a community package**: it repackages the official upstream build
  unmodified. A closed-source package that injects code says what it injects
  instead of "unmodified".
- **`project_license`** is the app's real licence; for closed source,
  `LicenseRef-proprietary=<URL of the vendor's terms>`.
- **Screenshots** are `<image>` URLs pointing at upstream, never files in the
  package. The site downloads them at build time and serves them as WebP,
  falling back to the upstream URL if the download fails.

### `resolve-update.sh`

Prints the latest release as JSON on stdout (logs go to stderr), and nothing
else. It does no hashing and touches no file:

```json
{
  "version": "1.2.3",
  "releaseDate": "2026-06-19",
  "sources": [
    { "filename": "app.tar.gz", "url": "https://example.com/app-1.2.3-linux-x86_64.tar.gz" }
  ]
}
```

- `filename` must match the one in the manifest.
- For several arches, emit one source per arch with `"arch": "x86_64"` or
  `"arch": "aarch64"`.
- If upstream re-uploads a fixed build under a new name (`1.2.3-2`), put the
  revision in `version`; otherwise the version compares equal and the new file
  is never pinned.
- Optional: `size` per source (re-pin when upstream silently replaces the file
  behind the same URL), `releaseUrl` and `releaseNotes` for the metainfo.
- Match the asset name tightly (anchor it, include the arch and extension). A
  loose pattern picks whichever variant sorts first when upstream adds one.
- Use `${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"}` on GitHub API
  calls; unauthenticated runs are rate-limited and fail.

Templates:

```sh
#!/usr/bin/env bash
# GitHub releases
set -euo pipefail
repo="owner/name"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
url="$(jq -r '.assets[] | select(.name | test("linux-x86_64\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve release" >&2; exit 1; }
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"app.tar.gz", url:$u}]}'
```

```sh
#!/usr/bin/env bash
# A vendor endpoint that reports the version
set -euo pipefail
version="$(curl -fsSL https://vendor.example/latest.txt)"
jq -n --arg v "$version" \
  '{version:$v, sources:[{filename:"app.deb", url:("https://vendor.example/app-"+$v+"_amd64.deb")}]}'
```

Run it locally with `cd registry/<id> && ./resolve-update.sh` and check that
the URL it prints downloads.

### What an update changes

Two triggers run the same steps:

- **Push:** upstream's release workflow calls FlatPark's hook, and
  `release-dispatch.yml` handles that one app within minutes.
- **Pull:** `update-check.yml` runs every resolver twice a day (06:17 and 18:17
  UTC) and catches everything else.

The steps:

1. Run `resolve-update.sh`. If its `version` equals the newest `<release>` in
   the metainfo, stop.
2. `scripts/update-pins.mjs` downloads every source, computes its SHA-256 and
   size, rewrites the managed block and prepends a `<release>` to the metainfo.
   **These two files are the only ones an update touches.**
3. `check-apply-extra.sh` unpacks the new download with the app's
   `apply_extra.sh`. If that fails, the app keeps its old pin and an alert issue
   is opened.
4. A PR is opened and merged by CI without review, as long as the diff touches
   only those two files (a resolver that writes anywhere else stops the merge).
   `publish.yml` then rebuilds only the changed apps, signs the repo and
   uploads it.
5. Users get the update on their next `flatpak update`, which downloads the new
   file and runs `apply_extra.sh` again.

`debian-pins.yml` re-pins the managed Debian blocks on its own schedule, because
Debian deletes a superseded package from its pool and new installs would fail
on the download while the app itself hasn't changed.

### Limits

What follows from extra-data, and what to do instead:

- **No source builds.** An official release makes them unnecessary, and they
  would cost CI time and storage on every update. When an app people want has
  no official Linux release at all, it can get a public
  `flatpark/<app>-release` repository that builds it on GitHub Actions exactly
  the way upstream does, unmodified and within upstream's licence, and
  publishes a release; the package pins that release as extra-data like any
  vendor download
  ([`com.ayugram.desktop`](../../registry/com.ayugram.desktop/com.ayugram.desktop.yml)
  pins `flatpark/ayugram-release`). That needs a maintainer's agreement first.
- **A library or tool the runtime lacks:** a second extra-data download (an
  upstream binary, a Debian package) or a [prebuilt stack](prebuilt.md#when-to-use-one).
  Don't compile it into `/app`.
- **The download must be a stable public URL with fixed bytes.** A URL that
  always serves "the latest" changes under the pin and fails installs until it
  is re-pinned; resolve it to a versioned URL. A CDN that serves different bytes
  per region breaks installs in some regions.
- **Nothing exported comes from the payload.** Desktop entry, icon, metainfo and
  D-Bus service files are ours, written at build time.
- **The payload runs unmodified.** Open-source apps get nothing injected and no
  file changed. Closed-source apps may, when nothing else works, and the
  metainfo says what and why. See the [packaging levels](../project/trust.md#packaging-changes).
- **One runtime major for the whole catalog.** An app that only works on an
  older runtime is not listed until it works on the current one.
