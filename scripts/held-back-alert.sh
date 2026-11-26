#!/usr/bin/env bash
# Open the "new payload no longer unpacks" alert for one app. Shared by the
# full sweep (update-check.yml) and the single-app update (update-app.yml), so
# a pin held back by either lands as the same `update-check/<id>` issue, and
# whichever of the two later verifies a payload for that app closes it.
#
# Usage: held-back-alert.sh <app-id>     (needs GH_TOKEN with issues:write)
set -euo pipefail
id="${1:?usage: held-back-alert.sh <app-id>}"
"$(dirname "${BASH_SOURCE[0]}")/ci-alert.sh" open "update-check/$id" \
    "update-check: $id no longer unpacks" <<MSG
The payload upstream is serving for \`$id\` fails this app's
\`apply_extra.sh\`, so the pin refresh was held back and the app stays on
the last version known to install. Users are not affected until this is
fixed and the new version ships.

Usually upstream repackaged — a renamed launcher, a relocated binary — and
\`registry/$id/apply_extra.sh\` needs to follow. Reproduce with:

\`\`\`
./scripts/check-apply-extra.sh $id
\`\`\`

This issue closes itself once that payload unpacks again.
MSG
