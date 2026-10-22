---
description: Shared support libraries built once in flatpark/prebuilt — what exists, when to use one, and how to add one.
order: 4
---

# Prebuilt stacks

Some apps need a library or tool that neither the Flatpak runtime nor the
vendor's download provides: a tray-icon library for Tauri apps, an `ffmpeg`
with subtitle support, the MariaDB client library. Rather than every package
compiling these from source, FlatPark builds each one once in
[`flatpark/prebuilt`](https://github.com/flatpark/prebuilt) and publishes it as
a release archive. A package pins that archive by URL, SHA-256 and size, like
any other download.

Prebuilt holds only open-source libraries that may be redistributed, built by
GitHub Actions from a manifest that pins every source and patch. It never holds
an app.

## The stacks

As of 2026-10-22. Sizes are the compressed archive. "Mode" is how packages pull
it in (see [archive or extra-data](#archive-module-or-extra-data)).

| Stack | Release | Built on | Size | What it is | Mode | Used by |
|---|---|---|---|---|---|---|
| `ayatana-stack` | `ayatana-v2` | GNOME 51 | 0.1 MB | libdbusmenu, ayatana-ido, libayatana-indicator, libayatana-appindicator: the tray library Tauri's `tray-icon` loads | archive | 19 Tauri apps with a tray icon, e.g. AeroFTP, Rayburst, DBX, NyaTerm |
| `appimage-tools` | `appimage-tools-v2` | fd 26.08 | 0.1 MB | `appimage-offset` and `unsquashfs`: open an AppImage without running it | extra-data | All 25 AppImage packages, e.g. Mark Shot, Compass |
| `mpv-stack` | `mpv-v2` | GNOME 51 | 1.3 MB | libmpv and the `mpv` player, with libass and libplacebo | archive | SubtitleEdit, PiliPlus |
| `libxdo` | `libxdo-v2` | GNOME 51 | <0.1 MB | `libxdo.so.3` (xdotool 3.x) for X11 input automation (the enigo crate) | archive | Vibe |
| `ffmpeg-full` | `ffmpeg-full-v3` | GNOME 51 | 13.0 MB | FFmpeg 9.0 `ffmpeg`/`ffprobe` with x264, x265, LAME, Rubber Band, libass, VAAPI, NVENC; ships those codec libraries too, so one pin is enough | extra-data | SubtitleEdit |
| `tesseract` | `tesseract-v2` | GNOME 51 | 1.6 MB | Tesseract 5.5 OCR library and CLI; no language data | extra-data | SubtitleEdit, Stirling PDF |
| `leptonica` | `leptonica-v2` | GNOME 51 | 1.2 MB | `libleptonica.so.6`, needed by `tesseract` | extra-data | SubtitleEdit, Stirling PDF |
| `uchardet` | `uchardet-v2` | GNOME 51 | 0.1 MB | `libuchardet.so.0`, guesses a text file's encoding | extra-data | SubtitleEdit |
| `sevenzip` | `sevenzip-v2` | GNOME 51 | 0.5 MB | 7-Zip `7zr`, `.7z` only | extra-data | SubtitleEdit |
| `poppler-glib` | `poppler-glib-v1` | GNOME 51 | 1.5 MB | `libpoppler-glib.so.8` and `libpoppler`, PDF rendering for GLib apps | extra-data | Strata, flux, Inua |
| `sql-clients` | `sql-clients-v1` | fd 25.08 | 0.5 MB | `libmariadb.so.3` with its auth plugins, `libpq.so.5`, `libsybdb.so.5`, `sshpass` | extra-data | [HeidiSQL](../../registry/com.heidisql.HeidiSQL/com.heidisql.HeidiSQL.yml) (on KDE 6.11, a 25.08 base) |
| `opencv-imgproc` | `opencv-imgproc-v3` | fd 26.08 | 4.4 MB | OpenCV 4.13 core and imgproc | extra-data | WeMeet (loaded by the screen-share hook) |
| `wemeet-screenshare-hook` | `wemeet-screenshare-hook-v2` | fd 26.08 | 0.1 MB | libportal and the XWayland screen-share hook | archive | WeMeet |
| `openssl-1.1-compat` | `openssl-1.1-compat-v2` | fd 26.08 | 1.3 MB | `libssl.so.1.1` and `libcrypto.so.1.1` for payloads that predate OpenSSL 3. **1.1.1 is end-of-life**: a last resort | extra-data | Tonghuashun (THS) |
| `krb5-gss` | `krb5-gss-v2` | fd 26.08 | 0.5 MB | `libgssapi_krb5.so.2` and its load-time closure, for a bundled Qt built with GSSAPI | extra-data | IBKR Desktop, the three Ely Office apps |

Each stack's manifest in `flatpark/prebuilt` says in its header why it exists,
what is left out and what to watch for. Read it before pinning the stack.

## When to use one

Work down this list, and stop at the first that fits:

1. **The runtime has it.** Check before anything else; a different runtime may
   too ([choosing a format](formats/README.md#choosing-the-runtime)).
2. **Upstream publishes a Linux binary of it.** Pin that as a second
   extra-data download.
3. **A distribution package works.** Pin the Debian package as extra-data in a
   managed block ([how](formats/deb.md#pinning-a-debian-package-for-a-missing-tool)).
4. **Prebuilt.** When no usable binary exists (the library has to be built with
   a particular option, like `ffmpeg` with libass), or when several apps need
   the same thing. Use the existing stack if there is one; otherwise add one.

Never compile a dependency inside an app's own manifest. Its bytes would land in
FlatPark's repository for that one app, and every package needing it would keep
its own copy of the recipe.

## For agents

### Archive module or extra-data

A stack can be consumed two ways, and the choice decides where its bytes live.

**Extra-data (the default).** The archive is downloaded from the GitHub release
at install time, next to the app's own download, and `apply_extra.sh` unpacks
it into `/app/extra/<stack>/`. Nothing is stored in FlatPark's repository.

```yaml
sources:
  # Outside the managed block: the updater rewrites that block whole.
  - type: extra-data
    filename: sql-clients.tar.xz
    only-arches: [x86_64]
    url: https://github.com/flatpark/prebuilt/releases/download/sql-clients-v1/sql-clients-sql-clients-v1-fd-25.08-x86_64.tar.xz
    sha256: …
    size: …
  # BEGIN MANAGED EXTRA-DATA
  # … the app's own download
  # END MANAGED EXTRA-DATA
```

```sh
# apply_extra.sh
bsdtar --no-same-owner -xf sql-clients.tar.xz
rm -f sql-clients.tar.xz
```

`/app/extra/<stack>/lib` is not on the loader's search path, so the app finds
nothing until the wrapper says where. Prefer the narrowest way that works:

- a tool's own wrapper or an environment variable the app reads (for example
  `TESSDATA_PREFIX`, `MARIADB_PLUGIN_DIR`);
- `LD_LIBRARY_PATH` in the app's wrapper only when the app itself links the
  library;
- `/app/etc/ld.so.conf` when the app discovers libraries through `ldconfig -p`,
  as HeidiSQL does.

**Archive module.** The archive is unpacked into `/app` at build time, so it
becomes part of the app's commit and is stored in FlatPark's repository.

```yaml
modules:
  - name: ayatana-stack
    buildsystem: simple
    build-commands:
      - cp -a ./. /app/
    sources:
      - type: archive
        url: https://github.com/flatpark/prebuilt/releases/download/ayatana-v2/ayatana-stack-ayatana-v2-gnome-51-x86_64.tar.xz
        sha256: 1051a537f22d335eb79557b8c5a610a12c326712dac74032de8e76e78b876fdc
  - name: app
    # …
```

Avoid it. Only the stacks the table already lists as `archive` are consumed
this way, `ayatana-stack` above all: many apps, one stored copy, because the
repository stores identical files once. A new stack, or a new consumer of a
stack that is extra-data elsewhere, goes in as extra-data.

`appimage-tools` must be extra-data whatever its use count: `apply_extra.sh`
runs it, and a system-wide install runs that script with only the runtime's
`/usr` and `/app/extra` visible. A copy in `/app/bin` passes a `--user` test
and fails on a system install.

Copy the current pin (URL, SHA-256 and, for extra-data, size) from a package
that already uses the stack, not from this page.

### A stack per runtime base

An archive is built against one SDK, and its file name says which:
`…-gnome-51-x86_64`, `…-fd-26.08-x86_64`. Pin one whose base matches the
app's runtime: GNOME 51 and freedesktop 26.08 share a base, and so do KDE 6.11
and freedesktop 25.08. Never pin an archive built for an older base to dodge a
rebuild.

When the catalog moves to a new runtime major, every stack is re-cut for it:

1. Measure first. Compare each stack's `DT_NEEDED` closure against the new
   runtime; a library that disappeared may need a newer component before the
   stack builds at all. (From the 25.08 to the 26.08 base, `mpv-stack` lost the
   whole `libav*` generation and needed a newer mpv; `ffmpeg-full` lost
   `libvpx.so.11`.)
2. Cut releases in dependency order. A stack that builds against another
   (`tesseract` on `leptonica`; `wemeet-screenshare-hook` on
   `opencv-imgproc`) needs its
   dependency's new release pinned in its manifest first.
3. Re-pin every consumer, and test one app per stack with its real feature.

### Adding or changing a stack

1. **Open a PR on `flatpark/prebuilt`** with a manifest named for the stack,
   not for an app (`libxdo.yml`, not `vibe-libs.yml`), so other packages can
   pin it. Start the file with a comment: why the runtime lacks it, the first
   consumer, what is deliberately left out, and anything a consumer must do.
2. **Pin every source** by URL and SHA-256, or by git tag and commit. Carry
   patches in `patches/<stack>/`.
3. **Build only what consumers need:** shared libraries and the tools apps run.
   Leave out headers unless another stack builds against it, and leave out
   docs, static libraries and unused front ends.
4. **Set both `no-debuginfo: true` and `strip: true`.** The first alone keeps
   full DWARF in every library.
5. **After merge, run the `release` workflow** (Actions → release → Run
   workflow) with a tag and the manifest. The tag is `<name>-v<N>`; the
   workflow reads the runtime from the manifest and names the asset
   `<stack>-<tag>-<base>-x86_64.tar.xz`, with a `.sha256` next to it.
6. **Never replace an asset on an existing tag.** A change is a new tag
   (`-v3`); consumers move to it in their own PRs.
7. **Pin it in the consuming package** and test that app's feature that needs
   the stack, inside the sandbox. A library that loads is not the same as a
   feature that works.

A release that no package pins any more is deleted (the tag stays), so the
release list only shows what is in use.

### What doesn't belong in prebuilt

- An app, or anything closed-source.
- A library only one app needs when a usable upstream or distribution binary
  exists (see the order above).
- Patches that change an app's behaviour. A stack supports apps from outside;
  it never stands in for a modified app.
