---
description: What to check when an app won't install, won't start, or forgets its settings, and how to report it.
order: 7
---

# Troubleshooting

- **App not found:** check the remote is there with `flatpak remotes`, and that
  the app id is spelled exactly as on its page. A per-user remote and a
  system-wide install (or the other way round) don't see each other; see
  [setting up](setup.md).
- **Signature or GPG errors:** add the remote again with the command from
  [setting up](setup.md); it carries the signing key.
- **"Wrong size" or a failed download while installing:** the app's file is
  downloaded from the developer's server at install time. If the developer
  replaced it, our pin no longer matches until it is updated, usually within a
  day. Try again later, and report it if it lasts.
- **The app won't start:** run it from a terminal to see why:
  `flatpak run <app-id>`.
- **An app disappeared from the catalog or was renamed:** a removed app keeps
  working until you uninstall it, but gets no more updates. A renamed app is a
  new id: install it under the new id from its page, then uninstall the old
  one. Your settings don't move over by themselves.
- **Settings are gone after a restart:** check you haven't turned off one of
  its folders ([flatpak override](override.md#common-cases)). If you
  haven't, it is a packaging bug; please report it.

## Reporting a problem

Open an issue at
[github.com/flatpark/flatpark/issues](https://github.com/flatpark/flatpark/issues)
with the app id, what you did, what happened, and the output of
`flatpak run <app-id>` from a terminal. Say which distribution and desktop you
use. Problems with how the app is packaged are ours to fix; we pass problems in
the app itself on to its developer.
