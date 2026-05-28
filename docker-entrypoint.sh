#!/bin/sh
# livesync-sync-docker entrypoint
#
# Smart auto-configuration wrapper for Self-hosted LiveSync CLI.
#
# Behaviours:
#   1. SETUP_URI provided via env → run setup command, then continue
#   2. No settings.json + COUCHDB_URL set → auto-generate from env vars
#   3. No command → default to "daemon" (continuous sync)
#   4. Otherwise → passthrough to livesync-cli

set -e

DATA_DIR="${LIVESYNC_DB_PATH:-/data}"
SETTINGS_FILE="${DATA_DIR}/.livesync/settings.json"
BIN="node /app/dist/index.cjs"

# ── Phase 1: Configuration ────────────────────────────────────────────────

# Priority 1: SETUP_URI takes precedence
if [ -n "${SETUP_URI}" ]; then
    echo "[livesync] Applying SETUP_URI configuration..."
    exec ${BIN} "${DATA_DIR}" setup "${SETUP_URI}"
fi

# Priority 2: Auto-configure from env vars if no settings file exists
if [ ! -f "${SETTINGS_FILE}" ] && [ -n "${COUCHDB_URL}" ]; then
    echo "[livesync] No existing settings found."
    echo "[livesync] Auto-configuring from environment variables..."
    node /app/init-settings.js
fi

# ── Phase 2: Run command ──────────────────────────────────────────────────

# Default to daemon if no command given
if [ $# -eq 0 ]; then
    echo "[livesync] Starting daemon (continuous sync)..."
    set -- daemon
fi

exec ${BIN} "${DATA_DIR}" "$@"
