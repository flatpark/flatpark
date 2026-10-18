---
description: Where FlatPark finds apps worth packaging, how to check one is wanted and not already served, and how to choose between them.
order: 0
---

# Finding apps

Most apps on FlatPark were found, not submitted. The aim is good desktop apps
that publish an official Linux build and that Flatpak users can't get yet, or
can only get in a broken or outdated form. These are the places to look, and
how to choose.

## Where to look

- **Popular apps on GitHub.** Desktop apps built with Electron, Tauri, Flutter,
  Qt, GTK and the like that publish Linux release files but no Flatpak
  repository. This is the widest channel.
- **Flathub submissions turned down for how they were made.** Many new apps
  submitted to Flathub are closed with an "AI Slop" label or a policy reason
  (an AI-written manifest, a requirement to build from source). Some are real,
  working apps, and they fit FlatPark well.
- **Other closed Flathub submissions.** Vendor apps submitted by third parties
  as extra-data and closed because the vendor hadn't consented, and apps whose
  submission went stale.
- **Flathub packages that fell behind.** Packages maintained by someone other
  than the developer that stopped following upstream releases, and packages
  Flathub marked end-of-life while upstream kept releasing. Their users are
  left on an old build with nowhere to go.
- **Requests.** Issues on FlatPark, and Flatpak requests on the app's own
  tracker.

## Choosing

Rank candidates by fit, not popularity. A couple of hundred GitHub stars is
already enough; past that, stars say nothing. A young project with few stars
can be a good pick if it is actively released and used. What matters:

- an official Linux build, released recently, at a stable URL;
- not on Flathub from its developer ([can it be packaged?](can-it-be-packaged.md));
- its main feature works in the sandbox;
- people want it: requests on its tracker, a Flathub attempt that stalled;
- a reasonable download size.

The best openings are developers who already want a Flatpak but haven't got
there: they build a `.flatpak` bundle but have no repository users can update
from, or they've said in an issue they'd like one and lack the time.

## For agents

Any agent can run a scan; you don't need to be a maintainer. The output is one
`[app discover]` issue per candidate (see [recording what you found](#recording-what-you-found)),
which anyone can then pick up and package. A run takes `gh` (logged in), `curl`
and `python3`.

### Before you start

Build the list of apps to skip, so you don't propose something already handled:

- apps in `registry/`: match on the `source_url`, `website` and `name` in each
  `flatpark.yml`;
- apps that were removed: `git log --oneline -i --grep='de-list'` names them.
  A removed app stays out unless something has changed;
- apps already proposed: `gh issue list -R flatpark/flatpark --state all --search '"[app discover]" in:title'`.

### GitHub popular apps

Search repositories by toolkit topic, recently pushed, then keep those whose
latest release has a Linux file. The search API returns at most 1000 results per
query and allows 30 queries a minute, so split each topic by star range and
pause between queries:

```sh
for t in tauri electron flutter-desktop wails gpui iced egui slint avalonia compose-desktop \
         qt6 gtk4 tauri-app electron-app desktop-app linux-app flutter-app dioxus; do
  for stars in 200..400 401..2000 '>2000'; do
    gh api -X GET search/repositories -f q="topic:$t stars:$stars pushed:>=<date>" \
      -f per_page=100 --paginate -q '.items[].full_name'
    sleep 2.5
  done
done | sort -u > candidates.txt
```

For each repository, list its recent releases
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

```sh
# turned down with the AI Slop label
gh api -X GET search/issues -f q='repo:flathub/flathub is:pr label:"AI Slop" created:>=<date>'

# closed without merging, other reasons
gh search prs --repo flathub/flathub --state closed --merged=false --base new-pr \
  --closed '<from>..<to>' --limit 1000 --json number,title,labels,url
```

For the second list, read the reviewers' comments for the reason, and look at
the diffs: a `type: extra-data` source marks a vendor binary someone tried to
submit. Flathub requires the vendor's consent for those; FlatPark doesn't, but
the vendor still decides whether it stays.

Most of the AI Slop list is days-old repositories with no users. Look for the
few that are established: a release history, issues from people other than the
author, and the author's own submission turned down on policy rather than on
the app.

### Per candidate

- **Demand:** `gh api -X GET search/issues -f q='repo:<owner>/<repo> flatpak in:title,body'`.
  Read the maintainer's replies; their concerns often name the real blocker.
- **Prior attempts:** `gh api -X GET search/issues -f q='repo:flathub/flathub is:pr <name> in:title'`,
  and why each closed.
- **Upstream's own Flatpak:** read the README. A `.flatpakref` or a
  `flatpak remote-add` line means upstream already runs a repository users can
  update from: skip it. A `.flatpak` bundle attached to releases with no
  repository behind it is the best opening there is, because FlatPark supplies
  the missing updates.
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

Open one issue per app in `flatpark/flatpark`, titled `[app discover] <Name>`,
with this body:

```md
Found by the app discovery scan (<YYYY-MM-DD>).

| | |
|---|---|
| Upstream | [owner/repo](https://github.com/owner/repo) |
| What it is | <one line, toolkit, stars> |
| Licence | <SPDX id> |
| Latest release | <version>, <date> |
| Linux files | <kinds and sizes> |
| Flathub | <not there / EOL / third-party package, with links> |

## Why there is demand

- <requests on its tracker with links and 👍 counts, closed Flathub attempts
  and why, the maintainer's own words>

## Notes for packaging

- <stack, sandbox concerns, permissions it will need, what to prototype>

## Next step

<Package it / Ask upstream first / Prototype X first>
```

Write it in English and link every claim. If there is no explicit demand, say
so and give the case that remains. An app you looked at and decided against
(say upstream prefers distribution packages) can get an issue too, with a
"Why we're holding off" section instead, so the next scan doesn't propose it
again.

Then package it with the [playbook](playbook.md), or leave the issue for
someone else to pick up.
