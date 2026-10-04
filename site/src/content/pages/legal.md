---
title: Privacy & terms
description: What FlatPark collects (almost nothing) and the terms for the packaged apps.
group: Legal
order: 1
---

## Privacy

FlatPark's website is a static site. It sets **no cookies**, runs **no
analytics**, and has **no accounts** — there is nothing to sign in to and nothing
we track about you.

App downloads are served from a content delivery network (Cloudflare
Pages / R2). Like any web server, the CDN may keep standard, short-lived access
logs (IP address, timestamp, requested file) for abuse prevention; FlatPark does
not use them to profile users.

To show how many people install each app, FlatPark counts installs and updates
as they happen. Flatpak itself tells the server which app it is fetching (the
`Flatpak-Ref` header) and whether it is an update; FlatPark records only that,
plus the country Cloudflare's edge reports, as an anonymous tally. No IP
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
listed in error, see the [de-listing process](/policies/) or open an issue.
