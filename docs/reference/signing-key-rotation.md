---
description: How the repository's GPG key is replaced without breaking existing installs, and where the current rotation stands.
---

# Signing key rotation

The repository key can be replaced without users doing anything, as long as
they update at least once while both keys are in use. A rotation has two
phases: an overlap, in which everything is signed with the outgoing and the
incoming key, and a switch, after which only the incoming key signs.

## How clients learn the new key

Every summary lists the public keys of its signing keys in its `xa.gpg-keys`
metadata (`publish-repo.sh`). On any install or update, and on
`flatpak remote-modify --update-metadata`, a client checks the summary
against a key it already trusts and then adds the listed keys to that remote's
keyring. This works for user and system installs (through the system helper,
without a password prompt) on every flatpak version tested, 1.12 to 1.16.

Clients only ever add keys this way. The outgoing key stays trusted on every
machine that had it, so a rotation moves signing to a new key, but it can't
revoke the old one on existing clients.

## Current rotation

| | Outgoing | Incoming |
|---|---|---|
| Fingerprint | `A2A6AE245C8B2FC3A5CCCC5487283E7A6DFC22BC` | `C7907AB1A4C3CF08614A882FCB843F54736642EF` |
| Signing subkey | `529EAFA2E08C1B81C4DCEE309FF8BFD0DE21F8E7` | `5812CEE578948B7A67BCE9B7C189B1A5BFFBEDA7` |
| CI secret (`production`) | `FLATPAK_GPG_PRIVATE_KEY` | `FLATPAK_GPG_KEY_2026_11` |
| Created | 2026-06-19; its master key was lost, so only the subkey exists | 2026-11-15; master backed up offline |

The overlap starts with the backfill run below. The switch is no earlier than
three months later.

## For agents

### Starting the overlap

1. Put the incoming signing subkey in the `production` environment next to the
   outgoing one, and import both in the "Import signing subkey" steps of
   `publish.yml` and `cleanup.yml`. Every key CI imports signs every
   commit and summary (`signing_keys` in `scripts/lib/common.sh`).
2. Run `publish.yml` by hand with **backfill_signatures** checked. It signs the
   current commit of every published ref with the incoming key, so a client
   that trusts only the incoming key can install apps nothing has rebuilt.
   `ostree gpg-sign` doesn't deduplicate, so the backfill checks each commit's
   signature key IDs first; it can be run again safely.
3. Check that the edge serves the new signatures. `*.commitmeta` objects hold
   the signatures and are now uploaded as revalidating (`sync-r2.sh`), but
   older ones carry a one-year immutable header. Cloudflare doesn't cache that
   extension by default (`cf-cache-status: DYNAMIC` on
   `https://dl.flatpark.org/objects/<xx>/<rest>.commitmeta`); if a cache rule
   ever makes it `HIT`, purge the cache for `dl.flatpark.org`.
4. Check that a client that trusts only the incoming key installs and updates.

### Switching

1. Delete the outgoing secret from the `production` environment. Publishing
   then signs with the incoming key only, and the summary and the
   `.flatpakrepo` and `.flatpakref` files list only it. No code change is
   needed.
2. Once nothing references the old secret's name any more, clean up the
   import steps.

### What a client that missed the overlap sees

`flatpak update` doesn't fail: it warns that it treats the fetch error as
non-fatal, says "Nothing to do", and exits 0, so the apps silently stop
updating. `flatpak remote-ls flatpark` shows the real error ("Can't check
signature: public key not found"). The fix is in
[troubleshooting](../users/troubleshooting.md).

### Testing

`tests/key-rotation/run.sh` runs a whole rotation in podman, with a server
running the real publish scripts and clients on flatpak 1.12, 1.14 and 1.16,
user and system installs. Run it after changing anything that signs.
