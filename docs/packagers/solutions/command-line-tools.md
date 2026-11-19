---
description: "Packaging command-line tools and local servers used in the browser: the catalog.interface field, file access by path, the terminal launcher."
order: 5
---

# Command-line tools and web UIs

Some packages have no window of their own. A command-line tool (FFmpeg,
yt-dlp, 7-Zip) is typed at in a terminal. A local server (llama.cpp,
stable-diffusion.cpp) runs in a terminal and is used through the page it
serves in the browser. Both launch from a `.desktop` with `Terminal=true`, and
both say which they are in `flatpark.yml`:

```yaml
catalog:
  interface: cli   # a command-line tool: the site shows "CLI"
  # interface: web # a local server used in the browser: the site shows "Web UI"
```

Leaving the field out means `gui`, an app with a window. The descriptor audit
fails a `Terminal=true` launcher that is left at `gui`, and `cli` without
`Terminal=true`. A server with only an API and no page, like `ollama serve`, is
`cli`.

## For agents

### Files are passed by path, so grant home

A GUI app gets the user's files through the file-chooser portal and needs no
grant. A command-line tool gets them as paths in its arguments, and the sandbox
sees only the directories the package grants. Outside them, things go wrong
without any error:

- **The working directory disappears.** When the shell's current directory is
  not visible in the sandbox, `flatpak run` starts the tool in the sandbox's own
  empty `$HOME`. `ffmpeg -i in.mp4 out.mkv` run from `~/Videos` with only
  `xdg-download` granted can't find `in.mp4`.
- **Output is lost.** A relative output path, or a tool that writes to the
  current directory by default (yt-dlp, gallery-dl), writes into that empty
  `$HOME`, which is a tmpfs. The command reports success and the file is gone
  when it exits.

A narrow grant (`xdg-download`, `xdg-pictures`) only works if users `cd` there
first, and a tool whose job is processing whatever file the user names has no
single right directory. Grant **`--filesystem=home`**, declare it under
`policy.dangerous_permissions` with one line on why, and say in the metainfo
what is not covered:

```yaml
policy:
  dangerous_permissions:
    # A command-line tool takes files as paths in its arguments; there is no
    # file chooser, and a working directory outside the grant is silently
    # replaced by the sandbox's empty home.
    - --filesystem=home
```

- **What home doesn't cover:** `/tmp` inside the sandbox is private, and
  external drives (`/run/media`, `/mnt`) are not in home. Give the override for
  them in the metainfo: `flatpak override --user --filesystem=/run/media <id>`.
- **`--persist` stops working** once home is granted. A tool's dotdir
  (`~/.android`) is then read from the real home, shared with a native install.
  That is usually what the user wants; drop the `--persist` line.
- **A tool that touches no user files** (a system monitor, a model server whose
  models live in its own storage) gets no file grant at all.
- **`--file-forwarding` is not a substitute.** `flatpak run --file-forwarding
  <id> @@ in.mp4 @@` exports existing files through the document portal, but
  can't create an output file and isn't something users type.

Standard input and output, pipes and exit codes pass through `flatpak run`
unchanged, and so does the terminal, so interactive tools and TUIs work.

### The launcher

`Exec=` in a terminal launcher should leave the user somewhere usable. For a
tool that takes arguments, open a shell in the home directory with a two-line
banner saying which commands it has and how to close it, as
[FFmpeg](../../../registry/org.ffmpeg.FFmpeg/ffmpeg-desktop) does. The tool's
binary on `PATH` inside the sandbox is then the command the user types.

From the user's own terminal the command is `flatpak run <id>`, and each extra
binary is `flatpak run --command=<name> <id>`. Put both in the metainfo
description; the app page shows them. Mark the `.desktop` `ConsoleOnly` in
`Categories` so menus that hide terminal programs can.

### Local servers used in the browser (`interface: web`)

- **Bind to loopback.** Start the server with `--host 127.0.0.1`, so the API
  isn't open to the network, and put the address in the `.desktop` `Comment`
  and the metainfo.
- **Open the page if the server can.** Use the server's own option
  (`speech serve --open`) rather than a wrapper that guesses when it is ready.
  Otherwise the metainfo tells the user which address to open and that the
  terminal must stay open. Ctrl+C stops it.
- **Editions get their own port.** CPU, CUDA and Vulkan editions installed side
  by side each default to a different port and keep separate model stores.
- **Files go through the page.** The browser uploads and downloads them, so
  the server needs no home grant. Model directories on the host are an
  optional read-only override in the metainfo.

Examples: [llama.cpp](../../../registry/io.github.ggml_org.LlamaCpp.CPU/flatpark.yml),
[speech.cpp](../../../registry/io.github.nyosegawa.SpeechCpp.CPU/io.github.nyosegawa.SpeechCpp.CPU.desktop).
