---
description: Where the desktop keeps your answers to permission dialogs (open with, screenshots, the camera, files you opened), and how to check and change them. With the calibre PDF example.
order: 5
---

# Permission store

Some things a sandboxed app can't do by itself: open a file with another
program, take a screenshot, use the camera, read a file you pick. It asks the
desktop instead, through a **portal**, and the desktop may show you a dialog.
Your answer is saved in Flatpak's **permission store**, so you aren't asked
every time.

This is separate from [flatpak override](override.md):

- `flatpak override` changes what the sandbox allows; you set it.
- The permission store remembers what you answered in a dialog; the desktop
  sets it.

So `flatpak override --reset` doesn't clear the permission store, and
uninstalling an app leaves its entries behind.

## Checking and resetting

```sh
flatpak permission-show <app-id>      # everything remembered for one app
flatpak permission-reset <app-id>     # forget all of it; you'll be asked again
flatpak permissions                   # everything, for every app
```

GNOME's Settings › Apps shows and changes some of these too; on other desktops
the commands above are the way.

## Example: choosing calibre's PDF reader

calibre doesn't show PDFs in its own viewer. It hands them to your desktop,
which asks which program to open them with. Pick the same reader a few times
and the dialog stops appearing: that choice is now remembered for calibre and
PDFs. To choose a different reader later, see what is remembered and remove it:

```sh
flatpak permissions desktop-used-apps application/pdf
# desktop-used-apps  application/pdf  com.calibre_ebook.calibre  org.gnome.Evince,3,3  0x00

flatpak permission-remove desktop-used-apps application/pdf com.calibre_ebook.calibre
```

The next PDF opens the dialog again. Other file types work the same way: use the
file's type in place of `application/pdf`; `xdg-mime query filetype <file>`
prints it. Every app has its own choice, so a reader picked in your browser
isn't the one calibre uses.

## Other answers you may want to change

| What you see | Command |
|---|---|
| A screenshot tool no longer asks, or was refused once and now always fails | `flatpak permission-remove screenshot screenshot io.github.jswysnemc.MarkShot` |
| An app was refused the camera, or you want to take it back | `flatpak permission-remove devices camera <app-id>` |
| A screen-sharing app always shares the same screen | `flatpak permissions screencast`, then `flatpak permission-remove screencast <id>` |
| An app can still open files you picked long ago | `flatpak documents <app-id>`, then `flatpak permission-remove documents <id> <app-id>` |

Removing an answer means you are asked again next time.

## For agents

### How it is stored

The store is a small database per table in `~/.local/share/flatpak/db/<table>`,
owned by the
`xdg-permission-store` D-Bus service. Change it only through `flatpak
permission-*` or the service; editing the files behind a running service is
lost or corrupts them.

Each entry is a table, an id within it, an app id, a list of permission strings,
and optional data:

```sh
flatpak permissions -j desktop-used-apps application/pdf
# [ { "table": "desktop-used-apps", "object": "application/pdf",
#     "app": "com.calibre_ebook.calibre", "permissions": "org.gnome.Evince,3,3", "data": "0x00" } ]
```

### Tables seen in practice

| Table | Id | Permissions | Written by |
|---|---|---|---|
| `desktop-used-apps` | a MIME type | `<handler app id>,<times picked>,<threshold>`; once the count reaches the threshold (3), the OpenURI portal stops asking | "Open with" (OpenURI portal) |
| `documents` | a document id | `read`, `write`, `grant-permissions`, `delete`; data holds the real path | File chooser, drag and drop, "open with" handing a file to another app |
| `screenshot` | `screenshot` | `yes` / `no` | Screenshot portal |
| `screencast` | a restore token | data holds the chosen output | ScreenCast portal "remember" |
| `devices` | `camera` | `yes` / `no` | Camera portal |
| `notifications` | `notification` | `yes` / `no` | Notification portal |
| `background` | `background` | `yes` / `no` | Background portal (GNOME) |

What a table contains depends on the desktop's portal backend; a table that
never appears on one desktop may be common on another.

### Changing entries

```sh
flatpak permission-remove <table> <id> <app-id>           # one app's answer: asked again
flatpak permission-remove <table> <id>                    # the whole entry, every app
flatpak permission-set <table> <id> <app-id> yes          # answer in advance
flatpak permission-set --data=<gvariant> <table> <id> <app-id> <perm>...
flatpak permission-reset <app-id>                         # every table, one app
```

- `documents`: each file handed to an app gets its own id, and the app reaches
  it as `/run/user/$UID/doc/<id>/<name>`. `flatpak documents <app-id>` lists
  them; `flatpak document-unexport --doc-id <id>` removes a document for every
  app. Screenshot tools and "open with" pile these up (one per file); that is
  harmless.
- Entries survive uninstalling. Clear an uninstalled app with
  `flatpak permission-reset <app-id>`.
- After a test, remove only the entries the test created. For an app the user
  also uses, never `permission-reset` it; their answers are in the same place.
- A private session bus used to fake a portal can start a second document
  portal and, when closed, unmount `/run/user/$UID/doc`; see
  [cleaning up after a run](../packagers/cleanup.md#checklist).
