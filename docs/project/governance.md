---
description: Who does what on FlatPark, and who has to agree before a change ships.
order: 5
---

# Governance

FlatPark is kept simple on purpose: a change should never wait for more people
than it needs. Day-to-day work, from a new listing to a removal, needs one
maintainer and an honest account of what was tested. Only changes to the rules
and the infrastructure ask for more.

## Roles

- **Maintainers** can merge. They keep the catalog, the infrastructure and the
  rules. Today there is one, the project's owner (@jing2uo).
- **Contributors** are everyone else who takes part: packaging apps, testing
  them, reporting problems, improving the docs.
- **Developers** of listed apps have the final word on their own app: whether
  it's listed, how it's packaged, what is said about it.

## Who agrees to what

| Change | What it needs |
|---|---|
| A new version from upstream | Nothing from a person: CI merges it once the new file unpacks |
| A new listing, a change to a package, a batch change, a removal | The PR says what was tested and what wasn't ([testing playbook](../reviewers/testing-playbook.md)), and one maintainer merges it |
| A developer's request about their own app | Applied as asked, in its own PR |
| [Principles](principles.md), the security floor, signing, infrastructure | A second maintainer's agreement, once there is more than one |
| A release found to steal data or damage systems | Pulled at once by any maintainer; see [security](security.md) |

- An app whose main feature can't be tested (an account, a login, hardware we
  don't have) isn't listed until its developer, or someone who can test it,
  confirms it works.
- A removal needs a stated reason; the reasons are in the
  [listing policies](policies.md#de-listing).

## Becoming a maintainer

Contributors whose packages and reviews have held up over time are invited by
the existing maintainers. A maintainer who steps back loses merge rights and
keeps their place in the history.

## Infrastructure

The flatpark.org domain and the Cloudflare account that serves the site and the
repository (Pages, R2, Workers) are currently provided by the owner personally.
When the project has partners for the long term, they move to an account the
project controls, so that no single person is required to keep it running.
