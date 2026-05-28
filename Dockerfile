# syntax=docker/dockerfile:1
#
# livesync-sync-docker
# Self-hosted LiveSync CLI — automated Docker build from upstream source.
#
# Build:
#   docker build --build-arg UPSTREAM_REF=main -t livesync-sync .
#
# Usage:
#   docker run --rm -v /path/to/vault:/data livesync-sync sync
#   docker run --rm -v /path/to/vault:/data livesync-sync daemon
#   docker run --rm -v /path/to/vault:/data livesync-sync daemon --interval 60
#
# Upstream: https://github.com/vrtmrz/obsidian-livesync/tree/main/src/apps/cli

ARG UPSTREAM_REF=main

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 — source
# Shallow-clone upstream repo (with submodules for the shared core).
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine/git:2.47.2 AS source
ARG UPSTREAM_REF
RUN git clone --depth 1 --recurse-submodules --shallow-submodules \
    https://github.com/vrtmrz/obsidian-livesync.git \
    -b ${UPSTREAM_REF} \
    /src

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 — builder
# Full Node.js environment to compile native modules and bundle the CLI.
# ─────────────────────────────────────────────────────────────────────────────
FROM node:22-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Leverage Docker layer cache: install deps before copying source
COPY --from=source /src/package.json /src/package-lock.json ./
RUN npm install

# Now copy full source and build
COPY --from=source /src .
RUN cd src/apps/cli && npm run build

# ─────────────────────────────────────────────────────────────────────────────
# Stage 3 — runtime-deps
# Install only the external (unbundled) runtime packages.
# Native addons compiled here against the same base as the final stage.
# ─────────────────────────────────────────────────────────────────────────────
FROM node:22-slim AS runtime-deps

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /deps

COPY --from=source /src/src/apps/cli/runtime-package.json ./package.json
RUN npm install --omit=dev

# ─────────────────────────────────────────────────────────────────────────────
# Stage 4 — runtime
# Minimal image: CLI bundle + pre-compiled native modules + smart entrypoint.
# ─────────────────────────────────────────────────────────────────────────────
FROM node:22-slim

WORKDIR /app

# Pre-compiled external node_modules from runtime-deps stage
COPY --from=runtime-deps /deps/node_modules ./node_modules

# Built CLI bundle from builder stage
COPY --from=builder /build/src/apps/cli/dist ./dist

# Official entrypoint (used internally by our wrapper for passthrough)
COPY --from=source /src/src/apps/cli/docker-entrypoint.sh /usr/local/bin/livesync-cli
RUN chmod +x /usr/local/bin/livesync-cli

# Custom auto-configuration script
COPY init-settings.js /app/init-settings.js

# Smart entrypoint — auto-configures from env vars, defaults to daemon
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

VOLUME ["/data"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
