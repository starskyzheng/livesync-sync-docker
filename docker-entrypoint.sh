#!/bin/sh
# livesync-sync-docker entrypoint
#
# Smart auto-configuration wrapper for Self-hosted LiveSync CLI.
#
# Flow:
#   1. SETUP_URI -> run setup, skip auto-config
#   2. No settings.json + COUCHDB_URL -> generate from env vars
#   3. Run `sync` once -> triggers CLI migration to full settings format
#   4. Inject encryption settings -> CLI migration resets them
#   5. No command given -> default to "daemon"
#   6. Otherwise -> passthrough

set -e

DATA_DIR="${LIVESYNC_DB_PATH:-/data}"
SETTINGS_FILE="${DATA_DIR}/.livesync/settings.json"
BIN="node /app/dist/index.cjs"

# ── Phase 1: Configuration ────────────────────────────────────────────────

if [ -n "${SETUP_URI}" ]; then
    echo "[livesync] Applying SETUP_URI configuration..."
    exec ${BIN} "${DATA_DIR}" setup "${SETUP_URI}"
fi

if [ ! -f "${SETTINGS_FILE}" ] && [ -n "${COUCHDB_URL}" ]; then
    echo "[livesync] No existing settings found."
    echo "[livesync] Auto-configuring from environment variables..."
    node /app/init-settings.js
fi

# ── Phase 2: Trigger CLI migration, then inject encryption ────────────────
# The CLI's "Migrating existing remote configuration" rewrites settings.json
# and drops encryption settings. We run sync first to trigger this migration,
# then inject encrypt/passphrase back so it sticks for the daemon run.

FIRST_RUN_FLAG="${DATA_DIR}/.livesync/.migrated"

if [ ! -f "${FIRST_RUN_FLAG}" ] && [ -f "${SETTINGS_FILE}" ]; then
    echo "[livesync] First run - triggering CLI migration..."
    # Run sync (may fail due to lock, that's OK - migration still happens)
    ${BIN} "${DATA_DIR}" sync 2>&1 || true
    
    # Now inject encryption settings (CLI migration cleared them)
    if [ -n "${ENCRYPT_PASSPHRASE}" ]; then
        echo "[livesync] Injecting encryption settings..."
        node -e "
            const fs = require('fs');
            const f = '${SETTINGS_FILE}';
            let d = JSON.parse(fs.readFileSync(f, 'utf-8'));
            d.encrypt = true;
            d.passphrase = '${ENCRYPT_PASSPHRASE}';
            d.P2P_IsHeadless = true;
            fs.writeFileSync(f, JSON.stringify(d, null, 2) + '\n');
            console.log('[livesync] Encryption enabled in settings.json');
        "
    fi
    
    touch "${FIRST_RUN_FLAG}"
    echo "[livesync] Migration complete, starting daemon..."
fi

# ── Phase 3: Run command ──────────────────────────────────────────────────

if [ $# -eq 0 ]; then
    echo "[livesync] Starting daemon (continuous sync)..."
    set -- daemon
fi

exec ${BIN} "${DATA_DIR}" "$@"
