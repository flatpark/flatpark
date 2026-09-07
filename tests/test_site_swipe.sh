#!/usr/bin/env bash
# Pointer gestures against the real carousel controller, with a minimal DOM.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v node >/dev/null 2>&1 || { echo "test_site_swipe: SKIP (no node)"; exit 0; }
node --test "$ROOT/tests/site_swipe.mjs"
