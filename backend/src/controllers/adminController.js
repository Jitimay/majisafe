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

/**
 * PATCH /api/admin/stations/:id — update station status, tank_level, etc.
 * Useful for testing without physical hardware.
 */
export function adminUpdateStation(req, res) {
  const { id } = req.params;
  const { status, tank_level } = req.body;
  const db = getDb();
  try {
    const station = db.prepare(`SELECT id FROM stations WHERE id = ?`).get(id);
    if (!station) {
      return res.status(404).json(apiError('STATION_NOT_FOUND', 'Station not found'));
    }
    const allowed = ['online', 'offline', 'dispensing', 'error'];
    if (status && !allowed.includes(status)) {
      return res.status(400).json(apiError('INVALID_STATUS', `status must be one of: ${allowed.join(', ')}`));
    }
    const fields = [];
    const params = [];
    if (status !== undefined)      { fields.push(`status = ?`);      params.push(status); }
    if (tank_level !== undefined)  { fields.push(`tank_level = ?`);  params.push(Number(tank_level)); }
    fields.push(`last_seen = datetime('now')`);
    params.push(id);
    db.prepare(`UPDATE stations SET ${fields.join(', ')} WHERE id = ?`).run(...params);
    const updated = db.prepare(`SELECT * FROM stations WHERE id = ?`).get(id);
    log('info', 'admin updated station', { id, status, tank_level });
    return res.json({ success: true, station: updated });
  } catch (e) {
    log('error', 'adminUpdateStation failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not update station'));
  }
}
