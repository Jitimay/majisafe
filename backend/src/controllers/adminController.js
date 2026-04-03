import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../models/db.js';
import { addCoins } from '../services/coinEngine.js';
import { insertLedgerTransaction, verifyLedgerChain } from '../services/ledger.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';

/**
 * Lists users (admin).
 */
export function listUsers(req, res) {
  try {
    const db = getDb();
    const rows = db
      .prepare(
        `SELECT id, phone, name, role, coin_balance, created_at FROM users ORDER BY id DESC LIMIT 500`
      )
      .all();
    return res.json({ success: true, users: rows });
  } catch (e) {
    log('error', 'listUsers failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not list users'));
  }
}

/**
 * Manual coin top-up with ledger entry.
 */
export function adminTopup(req, res) {
  const { user_id, coins, note } = req.body;
  const db = getDb();
  try {
    const u = db.prepare(`SELECT id FROM users WHERE id = ?`).get(user_id);
    if (!u) {
      return res.status(404).json(apiError('USER_NOT_FOUND', 'User not found'));
    }
    const txId = uuidv4();
    db.transaction(() => {
      addCoins(user_id, coins);
      insertLedgerTransaction(db, {
        id: txId,
        user_id,
        station_id: null,
        type: 'topup',
        coins,
        volume_litres: coins,
        payment_method: 'admin',
        status: 'confirmed',
        note: note || null,
      });
    })();
    const bal = db.prepare(`SELECT coin_balance FROM users WHERE id = ?`).get(user_id);
    return res.json({ success: true, tx_id: txId, new_balance: bal.coin_balance });
  } catch (e) {
    if (e.statusCode) {
      return res.status(e.statusCode).json(apiError(e.code, e.message));
    }
    log('error', 'adminTopup failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Top-up failed'));
  }
}

/**
 * Full ledger dump with hash-chain verification summary.
 */
export function auditLedger(req, res) {
  try {
    const db = getDb();
    const rows = db
      .prepare(`SELECT * FROM transactions ORDER BY datetime(created_at) ASC, id ASC`)
      .all();
    const breaks = verifyLedgerChain();
    return res.json({
      success: true,
      chain_valid: breaks.length === 0,
      breaks,
      transactions: rows,
    });
  } catch (e) {
    log('error', 'auditLedger failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Audit failed'));
  }
}

/**
 * Stations management view including non-public fields.
 */
export function adminStations(req, res) {
  try {
    const db = getDb();
    const rows = db.prepare(`SELECT * FROM stations ORDER BY id`).all();
    return res.json({ success: true, stations: rows });
  } catch (e) {
    log('error', 'adminStations failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not load stations'));
  }
}
