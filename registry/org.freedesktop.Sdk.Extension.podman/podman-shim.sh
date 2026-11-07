#!/usr/bin/env bash
# Installed as `podman`. Redirects to the first `podman` found on PATH
# outside this SDK extension when PODMAN_FLATPAK_FORCE_LOCAL is set
# (non-empty), redirects to podman-remote when PODMAN_FLATPAK_FORCE_REMOTE
# is set, otherwise runs the real podman binary (podman-cli).
set -euo pipefail

dir="$(dirname "$(readlink -f "$0")")"

if [ -n "${PODMAN_FLATPAK_FORCE_LOCAL-}" ]; then
  IFS=':' read -ra path_dirs <<< "${PATH-}"
  for path_dir in "${path_dirs[@]}"; do
    [ -n "${path_dir}" ] || continue
    [ "${path_dir}" = "${dir}" ] && continue
    if [ -x "${path_dir}/podman" ]; then
      exec "${path_dir}/podman" "$@"
    fi
  done
  echo "podman-shim: PODMAN_FLATPAK_FORCE_LOCAL is set but no podman was found on PATH outside ${dir}" >&2
  exit 1
fi

if [ -n "${PODMAN_FLATPAK_FORCE_REMOTE-}" ]; then
  exec "${dir}/podman-remote" "$@"
fi

exec "${dir}/podman-cli" "$@"
