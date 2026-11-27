# FlatPark CI image: the tools every workflow used to apt-get / curl | bash
# into a fresh runner on each job. Two targets, built for amd64 and arm64 by
# .github/workflows/ci-image.yml and pulled as ghcr.io/flatpark/ci:<target>:
#
#   base   node, rclone, gh, ostree and what the resolvers and scripts call on
#          the host (jq, curl, python3, file, xz, zstd, ar, 7z, bsdtar, gpg).
#          No flatpak-builder on purpose: tests/test_build_app.sh and
#          test_publish_e2e.sh self-skip without it, which lint-and-test relies on.
#   build  base + flatpak, flatpak-builder, bubblewrap, fuse3, appstream. Needs
#          `options: --privileged` in the job's container: (bwrap and
#          rofiles-fuse).
#
# Ubuntu, like the runners these jobs ran on, so resolvers see the same tools.
# 26.04 ships flatpak 1.16 on both arches, which also retires the
# ppa:flatpak/stable the arm runner needed for finish-args 1.14 rejected.
#
# Flathub runtimes are NOT baked in: they move independently of this image and
# build-app.sh installs/updates whatever each manifest asks for.
#
# Bump a pinned version: change it and its sha256 lines together (both from the
# release's checksums file), then let ci-image.yml rebuild on merge.

ARG UBUNTU=ubuntu:26.04

# Node 24 from the official image: 26.04's own nodejs is 22.
FROM docker.io/library/node:24-trixie-slim AS node

FROM docker.io/library/${UBUNTU} AS base
ARG TARGETARCH
ARG RCLONE_VERSION=1.76.0
ARG RCLONE_SHA256_amd64=b00f00b3266c3764413afe599d3ec316f6f43b3e0ea8a0bc1d186d2133e46df7
ARG RCLONE_SHA256_arm64=ee169016675e23a69d77240565133ff7dbc9b33d16fa8f7053d4af39f1eaeb78
ARG GH_VERSION=2.106.0
ARG GH_SHA256_amd64=a476449fa9625413c54a3734eded62e9e480e49f421ff08e7f3b3879c059a033
ARG GH_SHA256_arm64=5e8a0c51e1a8345f36bd0b8bb88604b6a5388df16f3ab3e3b9b6d794fa223a67

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git gnupg jq python3 file \
      xz-utils zstd bzip2 gzip unzip zip binutils 7zip libarchive-tools \
      ostree \
 && rm -rf /var/lib/apt/lists/*

# The job runs as root on a checkout owned by the runner's uid, and
# actions/checkout only trusts it for its own step: every later git call would
# die with "detected dubious ownership".
RUN git config --system --add safe.directory '*'

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && node --version && npm --version

RUN set -eu; arch="$TARGETARCH"; \
    eval "rclone_sha=\$RCLONE_SHA256_$arch gh_sha=\$GH_SHA256_$arch"; \
    tmp="$(mktemp -d)"; cd "$tmp"; \
    curl -fsSLo rclone.zip "https://downloads.rclone.org/v$RCLONE_VERSION/rclone-v$RCLONE_VERSION-linux-$arch.zip"; \
    echo "$rclone_sha  rclone.zip" | sha256sum -c -; \
    unzip -q rclone.zip; install -m755 "rclone-v$RCLONE_VERSION-linux-$arch/rclone" /usr/local/bin/rclone; \
    curl -fsSLo gh.tgz "https://github.com/cli/cli/releases/download/v$GH_VERSION/gh_${GH_VERSION}_linux_$arch.tar.gz"; \
    echo "$gh_sha  gh.tgz" | sha256sum -c -; \
    tar -xzf gh.tgz; install -m755 "gh_${GH_VERSION}_linux_$arch/bin/gh" /usr/local/bin/gh; \
    cd /; rm -rf "$tmp"; \
    rclone version | head -1; gh --version | head -1

FROM base AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      flatpak flatpak-builder bubblewrap fuse3 appstream \
      elfutils patch desktop-file-utils \
 && rm -rf /var/lib/apt/lists/*
