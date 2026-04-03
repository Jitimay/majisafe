import Database from 'better-sqlite3';
import path from 'path';
import fs from 'fs';
import bcrypt from 'bcrypt';
import { fileURLToPath } from 'url';
import { log } from '../utils/logger.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Opens the SQLite database, runs migrations, and seeds default station + admin.
 * @returns {import('better-sqlite3').Database}
 */
export function getDb() {
  if (globalThis.__majisafeDb) {
    return globalThis.__majisafeDb;
  }

  const dbPath = process.env.DB_PATH || path.join(process.cwd(), 'data', 'majisafe.db');
  const dir = path.dirname(dbPath);
  try {
    fs.mkdirSync(dir, { recursive: true });
  } catch (e) {
    log('error', 'failed to create db directory', { dir, err: String(e) });
    throw e;
  }

  let db;
  try {
    db = new Database(dbPath);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    runMigrations(db);
    seedIfNeeded(db);
  } catch (e) {
    log('error', 'database init failed', { err: String(e) });
    throw e;
  }

  globalThis.__majisafeDb = db;
  return db;
}

/**
 * Applies schema DDL and indexes in a single migration pass.
 * @param {import('better-sqlite3').Database} db
 */
function runMigrations(db) {
  try {
    db.exec(`
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT UNIQUE NOT NULL,
        name TEXT,
        password_hash TEXT,
        role TEXT DEFAULT 'user',
        coin_balance REAL DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS stations (
        id TEXT PRIMARY KEY,
        name TEXT,
        location TEXT,
        status TEXT DEFAULT 'offline',
        tank_level REAL DEFAULT 100,
        last_seen DATETIME,
        sim_number TEXT,
        dispense_url TEXT,
        api_secret TEXT
      );

      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        station_id TEXT REFERENCES stations(id),
        type TEXT,
        coins REAL,
        volume_litres REAL,
        payment_method TEXT,
        status TEXT,
        prev_hash TEXT,
        hash TEXT,
        progress_litres REAL,
        note TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS sms_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_number TEXT,
        message TEXT,
        parsed_amount REAL,
        parsed_tx_id TEXT,
        matched_user_id INTEGER,
        processed INTEGER DEFAULT 0,
        received_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS pending_topups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id),
        amount_bif REAL NOT NULL,
        method TEXT,
        note TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        fulfilled INTEGER DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS device_commands (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        station_id TEXT NOT NULL REFERENCES stations(id),
        tx_id TEXT NOT NULL,
        litres REAL NOT NULL,
        timeout_seconds INTEGER DEFAULT 60,
        status TEXT DEFAULT 'pending',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id);
      CREATE INDEX IF NOT EXISTS idx_device_commands_station ON device_commands(station_id, status);
      CREATE INDEX IF NOT EXISTS idx_pending_topups_user ON pending_topups(user_id, fulfilled);
    `);
    const ti = db.prepare(`PRAGMA table_info(transactions)`).all();
    if (!ti.some((c) => c.name === 'note')) {
      db.exec(`ALTER TABLE transactions ADD COLUMN note TEXT`);
    }
    if (!ti.some((c) => c.name === 'progress_litres')) {
      db.exec(`ALTER TABLE transactions ADD COLUMN progress_litres REAL`);
    }
    const ui = db.prepare(`PRAGMA table_info(users)`).all();
    if (!ui.some((c) => c.name === 'avatar_blob')) {
      db.exec(`ALTER TABLE users ADD COLUMN avatar_blob BLOB`);
    }
    if (!ui.some((c) => c.name === 'avatar_mime')) {
      db.exec(`ALTER TABLE users ADD COLUMN avatar_mime TEXT`);
    }
  } catch (e) {
    log('error', 'migration failed', { err: String(e) });
    throw e;
  }
}

/**
 * Inserts default station and promotes admin user by phone from env when missing.
 * @param {import('better-sqlite3').Database} db
 */
function seedIfNeeded(db) {
  try {
    const defaultSecret = process.env.STATION_DEFAULT_SECRET || 'station_shared_secret_change_me';
    const row = db.prepare(`SELECT id FROM stations WHERE id = ?`).get('STN-001');
    if (!row) {
      db.prepare(
        `INSERT INTO stations (id, name, location, status, tank_level, sim_number, dispense_url, api_secret)
         VALUES (?, ?, ?, 'offline', 100, NULL, NULL, ?)`
      ).run('STN-001', 'Regideso Central Demo', 'Bujumbura', defaultSecret);
      log('info', 'seeded default station STN-001');
    }

    const adminPhone = process.env.ADMIN_PHONE || '25761000000';
    const admin = db.prepare(`SELECT id, role FROM users WHERE phone = ?`).get(adminPhone);
    if (admin && admin.role !== 'admin') {
      db.prepare(`UPDATE users SET role = 'admin' WHERE id = ?`).run(admin.id);
      log('info', 'promoted user to admin', { phone: adminPhone });
    }
    if (!admin) {
      const hash = bcrypt.hashSync('admin-setup-change-me', 12);
      db.prepare(
        `INSERT INTO users (phone, name, password_hash, role, coin_balance)
         VALUES (?, 'Admin', ?, 'admin', 0)`
      ).run(adminPhone, hash);
      log('info', 'created admin user (change password)', { phone: adminPhone });
    }
  } catch (e) {
    log('error', 'seed failed', { err: String(e) });
    throw e;
  }
}
