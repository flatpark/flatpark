---
description: What FlatPark collects (almost nothing) and the terms for the packaged apps.
order: 9
---

# Privacy & terms

## Privacy

FlatPark's website is a static site. It sets **no cookies**, runs **no
analytics**, and has **no accounts** — there is nothing to sign in to and nothing
we track about you.

When you install or update an app, two servers are involved:

- **FlatPark's repository**, served by Cloudflare (Pages and R2), holds the
  small Flatpak package: the signed metadata and the files around the app.
  Cloudflare sees your IP address, like any web server, and may keep standard,
  short-lived access logs for abuse prevention.
- **The app itself** is downloaded straight from the developer's own servers,
  not through FlatPark. The developer sees your IP address too, and their
  privacy policy applies.

FlatPark doesn't collect IP addresses or other personal information itself,
and sells nothing.

To show how many people install each app, FlatPark counts installs and updates
as they happen. Flatpak itself tells the server which app it is fetching (the
`Flatpak-Ref` header), which version of it, and whether it is an update;
FlatPark records only that, plus the country Cloudflare's edge reports, as an
anonymous tally. No IP
address, user agent or anything else that could identify you or your machine
is stored. The daily totals are public at
[dl.flatpark.org/stats/](https://dl.flatpark.org/stats/totals.json).

## Terms

FlatPark's own code is provided **as is, without warranty of any kind**. FlatPark
only repackages official downloads — it does **not** license the packaged
applications. Each application remains the property of its vendor, is governed by
that vendor's own license, and is fetched from the vendor's official source at
install time.

Trademarks and brand names belong to their respective owners; their use here is
for identification only and does not imply endorsement. If you believe an app is
listed in error, see the [de-listing process](policies.md) or open an issue.
