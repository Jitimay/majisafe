import crypto from 'crypto';
import { getDb } from '../models/db.js';
import { log } from '../utils/logger.js';

/**
 * Computes SHA-256 ledger hash for a transaction row.
 * @param {string} id
 * @param {number|null} userId
 * @param {number} coins
 * @param {number|null} volumeLitres
 * @param {string} timestamp ISO string matching stored created_at
 * @param {string} prevHash
 */
export function computeTransactionHash(id, userId, coins, volumeLitres, timestamp, prevHash) {
  const payload = `${id}|${userId ?? ''}|${coins}|${volumeLitres ?? ''}|${timestamp}|${prevHash}`;
  return crypto.createHash('sha256').update(payload, 'utf8').digest('hex');
}

/**
 * Returns the hash of the most recent transaction for chaining, or GENESIS.
 */
export function getLastHash() {
  const db = getDb();
  return getLastHashInDb(db);
}

/**
 * @param {import('better-sqlite3').Database} db
 */
export function getLastHashInDb(db) {
  try {
    const row = db
      .prepare(`SELECT hash FROM transactions ORDER BY datetime(created_at) DESC, id DESC LIMIT 1`)
      .get();
    return row?.hash || 'GENESIS';
  } catch (e) {
    log('error', 'getLastHashInDb failed', { err: String(e) });
    throw e;
  }
}

/**
 * Inserts a ledger row with prev_hash/hash chain fields (call inside db.transaction).
 * @param {object} params
 * @param {import('better-sqlite3').Database} db
 */
export function insertLedgerTransaction(db, params) {
  const prevHash = getLastHashInDb(db);
  const now = new Date().toISOString();
  const id = params.id;
  const hash = computeTransactionHash(
    id,
    params.user_id,
    params.coins,
    params.volume_litres,
    now,
    prevHash
  );
  try {
    db.prepare(
      `INSERT INTO transactions (id, user_id, station_id, type, coins, volume_litres, payment_method, status, prev_hash, hash, progress_litres, note, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      id,
      params.user_id,
      params.station_id ?? null,
      params.type,
      params.coins,
      params.volume_litres ?? null,
      params.payment_method ?? null,
      params.status,
      prevHash,
      hash,
      params.progress_litres ?? null,
      params.note ?? null,
      now
    );
  } catch (e) {
    log('error', 'insertLedgerTransaction failed', { err: String(e) });
    throw e;
  }
  return { id, prev_hash: prevHash, hash, created_at: now };
}

/**
 * Verifies the full hash chain; returns broken link info or empty array.
 * @returns {{ index: number, id: string, expected?: string, actual?: string, kind?: string }[]}
 */
export function verifyLedgerChain() {
  const db = getDb();
  let prev = 'GENESIS';
  const breaks = [];
  try {
    const rows = db
      .prepare(`SELECT * FROM transactions ORDER BY datetime(created_at) ASC, id ASC`)
      .all();
    rows.forEach((row, index) => {
      if (row.prev_hash !== prev) {
        breaks.push({
          index,
          id: row.id,
          expected: prev,
          actual: row.prev_hash,
          kind: 'chain_prev_mismatch',
        });
      }
      const expectedHash = computeTransactionHash(
        row.id,
        row.user_id,
        row.coins,
        row.volume_litres,
        row.created_at,
        row.prev_hash
      );
      if (expectedHash !== row.hash) {
        breaks.push({
          index,
          id: row.id,
          expected: expectedHash,
          actual: row.hash,
          kind: 'row_hash_mismatch',
        });
      }
      prev = row.hash;
    });
  } catch (e) {
    log('error', 'verifyLedgerChain failed', { err: String(e) });
    throw e;
  }
  return breaks;
}
