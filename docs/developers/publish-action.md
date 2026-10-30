---
description: Add five lines to your release workflow and each GitHub release reaches FlatPark users within minutes.
order: 2
---

# Instant updates with publish-action

Without doing anything, your new releases reach FlatPark within half a day:
FlatPark checks every app's releases twice a day. If you release on GitHub, the
[publish-action](https://github.com/flatpark/publish-action) turns that into
minutes: your release workflow tells FlatPark the moment a release goes live,
and the update is checked and published right away.

It needs no token and no secret, and there is nothing else to maintain.

## Setting it up

Your app has to be listed on FlatPark already, with your GitHub repository as
its source. Then add a job to a workflow that runs when you publish a release:

```yaml
# .github/workflows/release.yml
on:
  release:
    types: [published]

jobs:
  flatpak:
    runs-on: ubuntu-latest
    # A FlatPark hiccup should never fail your release.
    continue-on-error: true
    steps:
      - uses: flatpark/publish-action@v1
        with:
          app-id: com.example.MyApp
```

Use your app's id on FlatPark; it is on your app's page.

### If a workflow creates your releases

GitHub doesn't start new workflow runs for events caused by the default
`GITHUB_TOKEN`. If your release is created by a workflow (`tauri-action`,
`softprops/action-gh-release` and the like), the `on: release` workflow above
never runs, and nothing reports it. Add the job to the workflow that creates
the release instead, after it is published, and pass the tag:

```yaml
jobs:
  release:
    # … builds and publishes the GitHub release …

  flatpak:
    needs: release
    runs-on: ubuntu-latest
    continue-on-error: true
    steps:
      - uses: flatpark/publish-action@v1
        with:
          app-id: com.example.MyApp
          tag: ${{ github.ref_name }}
```

The release must be **published**, not a draft, when the job runs, and its
Linux file uploaded. A release whose Linux file arrives later is picked up by
the twice-daily check.

## What happens after a release

1. The action sends your app id, the tag and your repository name to FlatPark.
2. FlatPark checks that the app is listed, that your repository is its
   registered source, and that the tag is a published release.
3. It finds the new Linux file, pins its checksum and size, and unpacks it the
   way an install would.
4. If that works, the update is merged and published without waiting for a
   person, usually within minutes. `flatpak update` delivers it to users.

If the new file doesn't unpack the way the package expects (a renamed binary,
a different archive layout), the update stops there. The previous version stays
available and FlatPark fixes the package by hand.

## Why it needs no secret

Nothing in the request is trusted as sent. FlatPark verifies all of it against
public facts: its own catalog, and the release on GitHub. So nobody can use the
action to publish a release for a repository they don't control, and your
workflow never holds a FlatPark credential.

## For agents

| Input | Required | Default | Meaning |
|---|---|---|---|
| `app-id` | yes | | The app's Flatpak id on FlatPark |
| `tag` | no | The triggering release's tag, else `GITHUB_REF_NAME` | The release to publish |
| `endpoint` | no | `https://hooks.flatpark.org/release` | The webhook |

- **The webhook** is a Cloudflare Worker (`workers/release-hook/`). It
  validates `{app_id, tag, repository}` against the published `catalog.json`
  (the app's `sourceUrl`, from `source_url` in `flatpark.yml`, must be that
  GitHub repository) and the GitHub release, then sends a `repository_dispatch`
  (`app-release`) to this repository with its own token. Errors: 404 for an
  unknown app id, 400 for a tag that isn't a release, 403 for a repository
  that isn't the app's source, 422 for an app without a GitHub source, 429 when
  rate-limited.
- **`release-dispatch.yml`** recomputes that one app's pins, unpacks the new
  payload with `check-apply-extra.sh`, opens `auto/release-<app-id>`, and merges
  it when the diff stays within the app's manifest and metainfo, the same
  terms as the twice-daily `update-check.yml`. The repository variable
  `AUTO_MERGE_PINS=false` stops both from merging.
- **Several releases on one day** give several small PRs, each published on its
  own. The twice-daily sweep supersedes any per-app PR still open.
- **`update.auto: false`** in the app's `flatpark.yml` makes both workflows skip
  it: that upstream sends its own update PR instead (see
  [basics](../packagers/basics.md#what-an-update-changes)). A ping for such an
  app is accepted and does nothing.
- **Which apps use it:** PRs from `auto/release-*` branches.
- **Packaging for an adopter:** set `source_url` to the GitHub repository the
  releases come from, or the webhook refuses the pings.
