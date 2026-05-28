#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const dataDir = process.env.LIVESYNC_DB_PATH || '/data';
const settingsDir = path.join(dataDir, '.livesync');
const settingsPath = path.join(settingsDir, 'settings.json');

// Required
const url = process.env.COUCHDB_URL;
if (!url) {
  console.error('[livesync] COUCHDB_URL is required');
  process.exit(1);
}

const settings = {
  couchDB_URI: url,
  couchDB_USER: process.env.COUCHDB_USER || '',
  couchDB_PASSWORD: process.env.COUCHDB_PASSWORD || '',
  couchDB_DBNAME: process.env.COUCHDB_DBNAME || 'obsidian-livesync',
  liveSync: process.env.LIVESYNC_ENABLE !== 'false',
  syncOnSave: process.env.SYNC_ON_SAVE !== 'false',
  syncOnStart: process.env.SYNC_ON_START !== 'false',
  encrypt: process.env.ENCRYPT === 'true',
  passphrase: process.env.ENCRYPT_PASSPHRASE || '',
  usePluginSync: false,
  isConfigured: true,
};

// Optional: periodic full replication
if (process.env.BATCH_SYNC_INTERVAL_SECONDS) {
  settings.batchSyncIntervalSeconds = Number(process.env.BATCH_SYNC_INTERVAL_SECONDS);
}
if (process.env.BATCH_SYNC_BASE_DELAY_SECONDS) {
  settings.batchSyncBaseDelaySeconds = Number(process.env.BATCH_SYNC_BASE_DELAY_SECONDS);
}

fs.mkdirSync(settingsDir, { recursive: true });
fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 4) + '\n');
console.log('[livesync] Settings written to ' + settingsPath);
