---
description: Where FlatPark finds apps worth packaging, how to check one is wanted and not already served, and how to choose between them.
order: 0
---

# Finding apps

Most apps on FlatPark were found, not submitted. The aim is good desktop apps
that publish an official Linux build and that people want as a Flatpak but
can't get yet, or can only get in a broken or outdated form. FlatPark goes by
demand: an app is a candidate because people are asking for it, not because of
where it came from.

## What counts as demand

A candidate needs at least one of these:

- **Someone asked for a Flatpak.** An issue or discussion on the app's own
  tracker asking for a Flatpak or a Flathub listing. Reactions and "+1"
  comments on it add weight; the maintainer's reply says whether they'd
  welcome one.
- **It is popular and missing from Flathub.** 1000 GitHub stars or more, and no
  Flathub package from its developer. At that size enough people run Linux that
  a Flatpak is wanted even if nobody has written the issue yet.
- **Its Flathub users were left behind.** A Flathub package that stopped
  following upstream or was marked end-of-life while upstream kept releasing.
  The people who installed it are the demand; Flathub's install counts and the
  issues on `github.com/flathub/<id>` show how many.

Where a lead came from doesn't count as demand by itself. In particular, an
app having been turned down by Flathub says nothing either way: it neither
qualifies an app nor rules it out.

## Where to look

- **Flatpak requests on GitHub.** Issues titled with "flatpak" or "flathub" on
  repositories of desktop apps that publish Linux release files. This is the
  most direct channel: the demand is already written down.
- **Popular apps on GitHub.** Desktop apps with 1000 stars or more, built with
  Electron, Tauri, Flutter, Qt, GTK and the like, that publish Linux release
  files but aren't on Flathub.
- **Flathub's closed submissions.** New-app PRs on `flathub/flathub` closed
  without merging, for whatever reason: a policy, a vendor binary submitted
  without the vendor's consent, a submission that went stale. Treat the list as
  names to check, not as candidates: most are young projects with no users yet,
  and each one still has to show demand like any other.
- **Flathub packages that fell behind.** Packages maintained by someone other
  than the developer that stopped following upstream releases, and packages
  Flathub marked end-of-life while upstream kept releasing.

`[App Request]` issues on FlatPark aren't a discovery channel: someone has
already asked, so the app is handled by [answering the request](#answering-an-app-request).
A scan only checks them so it doesn't propose the same app twice.

## Choosing

Demand gets an app onto the list; fit decides what to package first. Past the
demand bar, more stars don't make a better candidate. What matters:

- an official Linux build, released recently, at a stable URL;
- not on Flathub from its developer ([can it be packaged?](can-it-be-packaged.md));
- its main feature works in the sandbox;
- how strong the demand is: an open request with many reactions beats stars
  alone;
- a reasonable download size.

The best openings are developers who already want a Flatpak but haven't got
there: they build a `.flatpak` bundle but have no repository users can update
from, or they've said in an issue they'd like one and lack the time.

## For agents

Any agent can run a scan; you don't need to be a maintainer. The output is one
`[App Discover]` issue per scan, a table of every candidate it found (see
[recording what you found](#recording-what-you-found)); anyone can then pick a
row and package it. A run takes `gh` (logged in), `curl`
and `python3`.

### Before you start

Build the list of apps to skip, so you don't propose something already handled.
Match each candidate by upstream repository URL, then by name, then by id:

- **Listed:** every app in `registry/`, on the `source_url`, `website` and
  `name` in its `flatpark.yml`.
- **De-listed or declined:** every row in [de-listed apps](../reference/delisted.md).
  A developer who declined is skipped unless they have since said in public
  that they want FlatPark to carry the app; nobody asks them again. Every other
  row stays out unless the condition its section names has been met.
- **Already proposed or requested:** the tables in earlier scan issues and
  every app request, open or closed:
  `gh issue list -R flatpark/flatpark --state all --label app-discover` and
  `--label app-request`. An app someone has requested is answered on that
  request, not proposed again.

### Flatpak requests on GitHub

Search issues across GitHub for Flatpak requests, then keep the repositories
that are desktop apps with Linux release files. The search API returns at most
1000 results per query and allows 30 queries a minute, so split by creation
date and pause between queries:

```sh
for term in flatpak flathub; do
  for range in <from>..<mid> <mid>..<to>; do   # narrow the ranges until each returns under 1000
    gh api -X GET search/issues -f q="$term in:title is:issue created:$range" \
      -f per_page=100 --paginate \
      -q '.items[] | [.repository_url, .html_url, .reactions.total_count, .state] | @tsv'
    sleep 2.5
  done
done | sed 's#https://api.github.com/repos/##' | sort -u > requests.tsv
```

Drop issues that are about the project's own existing Flatpak (bug reports
against a Flathub package, build failures). Keep open requests, and closed ones
the maintainer closed as "not now" or "help wanted" rather than "no".

### GitHub popular apps

Search repositories by toolkit topic, 1000 stars and up, recently pushed:

```sh
for t in tauri electron flutter-desktop wails gpui iced egui slint avalonia compose-desktop \
         qt6 gtk4 tauri-app electron-app desktop-app linux-app flutter-app dioxus; do
  for stars in 1000..3000 '>3000'; do
    gh api -X GET search/repositories -f q="topic:$t stars:$stars pushed:>=<date>" \
      -f per_page=100 --paginate -q '.items[].full_name'
    sleep 2.5
  done
done | sort -u > candidates.txt
```

### Release files

For each repository from either list, list its recent releases
(`gh api 'repos/<repo>/releases?per_page=5'`), take the newest that isn't a
draft or prerelease, and look for an x86_64 `.deb`, `.tar.gz`, `.zip`, AppImage
or `.flatpak` published in the last few months. Drop everything on the skip
list.

### Flathub checks

- Match against Flathub's full AppStream data, which has every app's id, name
  and URLs:
  `curl -sL https://dl.flathub.org/repo/appstream/x86_64/appstream.xml.gz`.
  Match by upstream repository URL first, then by name, then by id. The id list
  alone (`https://flathub.org/api/v2/appstream`) misses apps whose id doesn't
  contain the repository name. Flathub's search endpoint misses many apps that
  are there; don't rely on it.
- For an app that is there, look at who commits to `github.com/flathub/<id>`.
  The developer or a project member means it is theirs: skip it. A third party,
  or Flathub's own maintainers keeping it alive, means it may qualify with a
  reason.
- An app missing from the AppStream data may still have a repository at
  `github.com/flathub/<id>`. If that repository is archived and its
  `flathub.json` has `end-of-life`, the app was dropped. If upstream still
  releases, that is a good candidate, and keeping the old id gives its users
  somewhere to go.
- Whether upstream's repository has a Flatpak manifest says nothing about who
  owns the Flathub entry.

### Flathub's closed submissions

One list covers every reason a submission was closed:

```sh
gh search prs --repo flathub/flathub --state closed --merged=false --base new-pr \
  --closed '<from>..<to>' --limit 1000 --json number,title,url
```

Don't filter or rank by the labels reviewers put on these PRs; a label is not a
reason to pick an app or to skip one. For each, find the upstream repository and
run the [demand check](#per-candidate). Keep only the apps that pass: a request
on their tracker, 1000 stars or more, or established users (a release history,
issues from people other than the author).

Read the reviewers' comments for why it closed, and look at the diff: a
`type: extra-data` source marks a vendor binary someone tried to submit. Flathub
requires the vendor's consent for those; FlatPark doesn't, but the vendor still
decides whether it stays.

### Per candidate

- **Demand:** `gh api -X GET search/issues -f q='repo:<owner>/<repo> flatpak in:title,body'`,
  and the star count. Note which [signal](#what-counts-as-demand) the app
  meets; without one, it isn't a candidate. Read the maintainer's replies;
  their concerns often name the real blocker.
- **Prior attempts:** `gh api -X GET search/issues -f q='repo:flathub/flathub is:pr <name> in:title'`,
  and why each closed.
- **Upstream's own Flatpak:** read the README. A `.flatpakref` or a
  `flatpak remote-add` line means upstream runs its own repository. That
  doesn't rule the app out: as long as it isn't on Flathub, it can be listed,
  provided the release also has a file FlatPark can pin as extra-data (a
  tarball, `.deb` or AppImage; the OSTree repository itself can't be pinned).
  Ask upstream first and list it with their agreement. One FlatPark remote
  instead of a remote per app means fewer remotes for users to add. A `.flatpak`
  bundle attached to releases with no repository behind it is the best opening
  there is, because FlatPark supplies the missing updates.
- **The developer's own plans:** an open Flathub PR by the maintainer, or a
  statement that they're working on an official Flatpak, means skip it. A
  manifest prepared in their repository but never submitted, or a "we'd take it
  if someone did the work", means ask them first.
- **Licence:** GitHub reports many licences as `NOASSERTION`; read the file
  (`gh api repos/<repo>/license`).
- **Commonly out:** VPN and proxy clients that need a TUN device, apps whose main
  job is to change the host (hosts files, system settings), apps that drive a
  host toolchain or daemon (Docker, KVM, a host CLI), and apps with no licence
  that aren't vendor binaries.

### Recording what you found

Open one issue per scan in `flatpark/flatpark`, titled
`[App Discover] Scan <YYYY-MM-DD>: <n> candidates` and labelled `app-discover`,
with this body:

```md
Found by the app discovery scan (<YYYY-MM-DD>), following [finding apps](https://github.com/flatpark/flatpark/blob/main/docs/packagers/finding-apps.md).

Scan windows: <what each channel covered, with dates>. Each candidate meets a
demand signal: <the signals used>. None of them is in the registry, de-listed,
or already proposed or requested.

| # | App | What it is | Stars | Licence | Demand | Linux files |
|---|---|---|---:|---|---|---|
| 1 | [<Name>](https://github.com/owner/repo) | <one line> | <stars> | <SPDX id> | <the signal, linked: request #n with its reaction count and the maintainer's words / stars only / left-behind Flathub package> | <kinds and sizes> |

<Caveats that apply to some rows: a maintainer working on their own Flatpak,
upstream preferring other channels, a self-hosted remote. Name the rows.>

## Held off

| App | Why |
|---|---|
| [<Name>](https://github.com/owner/repo) | <the concrete reason, linked> |

To package one, comment `/claim <App>` or `/claim <#>` here and follow the
[per-candidate steps](https://github.com/flatpark/flatpark/blob/main/docs/packagers/finding-apps.md#per-candidate).
```

Write it in English and link every claim. Order the rows by strength of demand:
explicit requests first, by reactions, then stars alone. Only list an app that
meets a [demand signal](#what-counts-as-demand); if it qualifies on stars alone,
the Demand cell says so. Don't rank candidates into tiers or hold one back as
"too young": demand is enough. Only a concrete reason (the developer's own
Flathub PR or stated plan, upstream declining, a hard sandbox blocker) moves an
app to **Held off**, which keeps the next scan from proposing it again; leave
the section out if it is empty. Packaging concerns are for whoever picks the
row up, not reasons to hold off.

Number the rows from 1; a claim can name a row by its number. Whoever
packages a row comments `/claim <App>` or `/claim <#>` on the scan issue first
([claims](../reviewers/issues.md#claims)), and links the issue from the PR
(`Refs #<n>`, not `Closes`, since the other rows stay open). Close the scan
issue once every row is packaged or ruled out; a later scan's skip list
already covers its rows.

### Answering an app request

An `[App Request]` issue may hold no more than a name or a link; the form
asks for nothing else on purpose. Fill in the rest yourself:

1. Find the app: the link, or a search by name. If two apps share the name,
   ask which one, add `needs-info`, and stop there.
2. Check it as for any candidate ([per candidate](#per-candidate),
   [Flathub checks](#flathub-checks), [can it be packaged?](can-it-be-packaged.md)),
   and look for an earlier request:
   `gh issue list -R flatpark/flatpark --state all --search '<name> in:title'`.
   A duplicate gets a link to the earlier issue and is closed as a duplicate.
3. Comment with what you found, in this shape:

   ```md
   Looked up for this request (<YYYY-MM-DD>).

   | | |
   |---|---|
   | Upstream | [owner/repo](https://github.com/owner/repo) |
   | What it is | <one line, toolkit, stars> |
   | Licence | <SPDX id> |
   | Latest release | <version>, <date> |
   | Linux files | <kinds and sizes> |
   | Flathub | <not there / EOL / third-party package, with links> |

   ## Why there is demand

   - <this request; requests on its tracker with links and 👍 counts; earlier
     Flathub attempts and why they closed>

   ## Notes for packaging

   - <stack, sandbox concerns, permissions it will need, what to prototype>

   ## Next step

   <Package it / Ask upstream first / Prototype X first>
   ```

   Anything the requester wrote (what they use it for, the download, a Flathub
   package) goes in with credit.
4. Don't edit the requester's text, and don't rename the issue beyond
   `[App Request] <Name>`.

An app that can't be listed gets the same table and a **Why we can't list it**
section in place of **Next step**, linking the rule; then close the issue as
not planned. That includes an app in [de-listed apps](../reference/delisted.md)
whose condition hasn't been met, linking its row. A request from the developer
of a declined or withdrawn app is the yes those sections wait for: it can be
listed, and the request is the evidence.
