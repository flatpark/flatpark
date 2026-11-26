---
description: Packaging an app from upstream's portable tarball or zip.
order: 1
---

# Tarballs and zips

A portable tarball is the easiest payload: one directory holding the app and the
libraries it bundles, made to run from wherever it is unpacked. `apply_extra.sh`
unpacks it, renames the directory to a fixed path, and the wrapper runs the
binary inside. A zip works the same way; `bsdtar` reads both.

Start from one of these:

- [Grab](../../../registry/io.github.linuxuser67.Grab/apply_extra.sh): a GTK 4
  app shipped as an install tree, on the GNOME runtime.
- [Electerm](../../../registry/org.electerm.Electerm/apply_extra.sh): an
  Electron app with a version-stamped top directory, on the freedesktop runtime
  with the Electron base app.
- [Impasto](../../../registry/io.github.zbcoding.Impasto/apply_extra.sh): a zip.

## For agents

### `apply_extra.sh`

```sh
#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The tarball is the
# official portable build: one versioned top directory with the executable,
# its bundled libraries and plugins. Rename it to a stable path so the
# wrapper can exec it across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.tar.gz ] || { echo "missing extra-data: app.tar.gz" >&2; exit 1; }

rm -rf stage app
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf app.tar.gz -C stage

top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] || { echo "expected one top-level directory" >&2; exit 1; }
mv "$top" app
[ -x app/example ] || { echo "example binary not found in the tarball" >&2; exit 1; }

rm -rf stage app.tar.gz
```

- **Unpack into a staging directory**, then move the one tree you want into
  place. Don't trust the archive's top-level name: it usually carries the
  version, and some archives have no top directory at all. Test for exactly
  what you expect and fail if it isn't there.
- **Never hardcode a name upstream can change** between releases (the version
  in the directory, sometimes the launcher's name). Updates are merged without
  a human; read the name from the archive, or match it with a pattern and
  check there is exactly one (Electerm matches `electerm-*-linux-*`).
- **`rm -rf` the old copy first.** The script runs again on every update in the
  same `/app/extra`.
- **Zips lose nothing with `bsdtar`,** including Unix permissions, as long as
  upstream zipped on Unix. A zip made on Windows has no executable bits; then
  `chmod +x` the binaries you know about.
- **Other compressions** (`.tar.xz`, `.tar.zst`, `.tar.bz2`) need no flag;
  `bsdtar` detects them.

### The wrapper

```sh
#!/bin/sh
set -eu
# Bundled plugins and libraries stay inside the portable tree.
export LD_LIBRARY_PATH="/app/extra/app/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd /app/extra/app
exec /app/extra/app/example "$@"
```

Only add `LD_LIBRARY_PATH` or a `cd` when the app needs them: most portable
builds find their own libraries through an `$ORIGIN` RUNPATH, and an
`LD_LIBRARY_PATH` that points into the bundle also applies to every program
the app starts.

### Electron tarballs and zips

- Use `base: org.electronjs.Electron2.BaseApp` (same version as the
  freedesktop runtime) and start the app with
  `exec zypak-wrapper /app/extra/app/<launcher> --ozone-platform-hint=auto "$@"`.
  zypak puts Chromium's sandbox on top of Flatpak's, so the app keeps it;
  never use `--no-sandbox` for an Electron app.
- `unset ELECTRON_RUN_AS_NODE` in the wrapper. If it leaks in from the user's
  terminal, the binary starts as Node instead of the app.
- `chrome-sandbox` is unused under zypak. Leave it, but if the archive records
  it setuid, clear the bit: `chmod -R a-s app`.
- The window class an Electron app sets is its product name, not the binary or
  the app id. Measure it before writing `StartupWMClass` in the desktop entry.

### Checks before the PR

```sh
./scripts/check-apply-extra.sh <app-id>     # unpacks as a system install would
./scripts/publish.sh --verify <app-id>      # builds and installs it
```

Then run the app and use its core feature; see
[submitting an app](../submitting.md#test).
