import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../models/db.js';
import { deductCoins, refundCoins } from '../services/coinEngine.js';
import { insertLedgerTransaction } from '../services/ledger.js';
import { sendDispenseHttp } from '../services/dispensingService.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';

/**
 * Deducts coins, writes ledger, enqueues device command, and optionally POSTs to station URL.
 */
export async function requestDispense(req, res) {
  const { station_id, litres } = req.body;
  const userId = req.user.id;
  const db = getDb();

  try {
    const station = db.prepare(`SELECT * FROM stations WHERE id = ?`).get(station_id);
    if (!station) {
      return res.status(404).json(apiError('STATION_NOT_FOUND', 'Station not found'));
    }
    if (station.status === 'offline' || station.status === 'error') {
      return res.status(400).json(apiError('STATION_UNAVAILABLE', 'Station is not available'));
    }

    const txId = uuidv4();
    const timeout_seconds = 60;

    db.transaction(() => {
      deductCoins(userId, litres);
      insertLedgerTransaction(db, {
        id: txId,
        user_id: userId,
        station_id,
        type: 'dispense',
        coins: litres,
        volume_litres: litres,
        payment_method: 'app',
        status: 'pending',
      });
      db.prepare(
        `INSERT INTO device_commands (station_id, tx_id, litres, timeout_seconds, status) VALUES (?, ?, ?, ?, 'pending')`
      ).run(station_id, txId, litres, timeout_seconds);
      db.prepare(`UPDATE stations SET status = 'dispensing', last_seen = datetime('now') WHERE id = ?`).run(station_id);
    })();

    const url = station.dispense_url && String(station.dispense_url).trim();
    if (url) {
      const ok = await sendDispenseHttp(url, { tx_id: txId, litres, timeout_seconds });
      if (!ok) {
        db.transaction(() => {
          refundCoins(userId, litres);
          insertLedgerTransaction(db, {
            id: uuidv4(),
            user_id: userId,
            station_id,
            type: 'refund',
            coins: litres,
            volume_litres: litres,
            payment_method: 'app',
            status: 'confirmed',
            note: `Station unreachable after retries; refund for ${txId}`,
          });
          db.prepare(`UPDATE transactions SET status = 'failed' WHERE id = ?`).run(txId);
          db.prepare(`UPDATE device_commands SET status = 'aborted' WHERE tx_id = ?`).run(txId);
          db.prepare(`UPDATE stations SET status = 'online', last_seen = datetime('now') WHERE id = ?`).run(station_id);
        })();
        log('warn', 'dispense dispatch failed; refunded', { txId, station_id, userId });
        return res
          .status(503)
          .json(apiError('STATION_UNREACHABLE', 'Station did not acknowledge after 3 attempts; coins were refunded.'));
      }
    }

    return res.json({ success: true, tx_id: txId, station_id, litres, timeout_seconds });
  } catch (e) {
    if (e.statusCode) {
      return res.status(e.statusCode).json(apiError(e.code, e.message));
    }
    log('error', 'requestDispense failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Dispense request failed'));
  }
}

/**
 * Records actual litres from hardware; refunds any shortfall and closes the command.
 */
export function confirmDispense(req, res) {
  const { station_id, tx_id, actual_litres } = req.body;
  const db = getDb();
  try {
    if (req.stationId && station_id !== req.stationId) {
      return res.status(400).json(apiError('STATION_MISMATCH', 'Station mismatch'));
    }
    const row = db.prepare(`SELECT * FROM transactions WHERE id = ?`).get(tx_id);
    if (!row || row.type !== 'dispense') {
      return res.status(404).json(apiError('TX_NOT_FOUND', 'Transaction not found'));
    }
    if (row.station_id !== station_id) {
      return res.status(400).json(apiError('STATION_MISMATCH', 'Station mismatch'));
    }
    if (row.status !== 'pending') {
      return res.status(400).json(apiError('INVALID_STATE', 'Transaction already finalized'));
    }

    const requested = Number(row.coins);
    const actual = Number(actual_litres);

    db.transaction(() => {
      if (actual < requested) {
        const diff = requested - actual;
        refundCoins(row.user_id, diff);
        insertLedgerTransaction(db, {
          id: uuidv4(),
          user_id: row.user_id,
          station_id,
          type: 'refund',
          coins: diff,
          volume_litres: diff,
          payment_method: 'app',
          status: 'confirmed',
          note: `Dispense shortfall refund for ${tx_id}`,
        });
      }
      db.prepare(
        `UPDATE transactions SET status = 'confirmed', volume_litres = ?, progress_litres = ? WHERE id = ?`
      ).run(actual, actual, tx_id);
      db.prepare(`UPDATE device_commands SET status = 'done' WHERE tx_id = ?`).run(tx_id);
      db.prepare(`UPDATE stations SET status = 'online', last_seen = datetime('now') WHERE id = ?`).run(station_id);
    })();

    return res.json({ success: true, tx_id, actual_litres: actual });
  } catch (e) {
    log('error', 'confirmDispense failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Confirm failed'));
  }
}

/**
 * Full coin refund on hardware/flow failure.
 */
export function abortDispense(req, res) {
  const { station_id, tx_id, reason } = req.body;
  const db = getDb();
  try {
    if (req.stationId && station_id !== req.stationId) {
      return res.status(400).json(apiError('STATION_MISMATCH', 'Station mismatch'));
    }
    const row = db.prepare(`SELECT * FROM transactions WHERE id = ?`).get(tx_id);
    if (!row || row.type !== 'dispense') {
      return res.status(404).json(apiError('TX_NOT_FOUND', 'Transaction not found'));
    }
    if (row.station_id !== station_id) {
      return res.status(400).json(apiError('STATION_MISMATCH', 'Station mismatch'));
    }
    if (row.status !== 'pending') {
      return res.status(400).json(apiError('INVALID_STATE', 'Transaction already finalized'));
    }

    const requested = Number(row.coins);

    db.transaction(() => {
      refundCoins(row.user_id, requested);
      insertLedgerTransaction(db, {
        id: uuidv4(),
        user_id: row.user_id,
        station_id,
        type: 'refund',
        coins: requested,
        volume_litres: requested,
        payment_method: 'app',
        status: 'confirmed',
        note: reason || `Dispense abort refund for ${tx_id}`,
      });
      db.prepare(`UPDATE transactions SET status = 'refunded' WHERE id = ?`).run(tx_id);
      db.prepare(`UPDATE device_commands SET status = 'aborted' WHERE tx_id = ?`).run(tx_id);
      db.prepare(`UPDATE stations SET status = 'online', last_seen = datetime('now') WHERE id = ?`).run(station_id);
    })();

    return res.json({ success: true, tx_id, refunded_coins: requested });
  } catch (e) {
    log('error', 'abortDispense failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Abort failed'));
  }
}

/**
 * Returns current dispense transaction state for the mobile app (poll).
 */
export function dispenseStatus(req, res) {
  const { txId } = req.params;
  const db = getDb();
  try {
    const t = db.prepare(`SELECT * FROM transactions WHERE id = ? AND user_id = ?`).get(txId, req.user.id);
    if (!t) {
      return res.status(404).json(apiError('TX_NOT_FOUND', 'Transaction not found'));
    }
    const actual_litres = t.status === 'confirmed' ? Number(t.volume_litres) : null;
    return res.json({
      success: true,
      status: t.status,
      tx_id: t.id,
      requested_litres: Number(t.coins),
      progress_litres: t.progress_litres != null ? Number(t.progress_litres) : null,
      actual_litres,
      station_id: t.station_id,
    });
  } catch (e) {
    log('error', 'dispenseStatus failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Status failed'));
  }
}

/**
 * Device poll: returns one pending command and marks it sent.
 */
export function getPendingDeviceCommand(req, res) {
  const stationId = req.stationId;
  const db = getDb();
  try {
    let row;
    db.transaction(() => {
      row = db
        .prepare(
          `SELECT * FROM device_commands WHERE station_id = ? AND status = 'pending' ORDER BY id ASC LIMIT 1`
        )
        .get(stationId);
      if (row) {
        db.prepare(`UPDATE device_commands SET status = 'sent' WHERE id = ?`).run(row.id);
      }
    })();
    if (!row) {
      return res.json({ success: true, command: null });
    }
    return res.json({
      success: true,
      command: {
        tx_id: row.tx_id,
        litres: row.litres,
        timeout_seconds: row.timeout_seconds,
      },
    });
  } catch (e) {
    log('error', 'getPendingDeviceCommand failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not read command'));
  }
}

/**
 * Optional progress updates from firmware for UI polling.
 */
export function progressDispense(req, res) {
  const { tx_id, current_litres } = req.body;
  const db = getDb();
  try {
    const t = db
      .prepare(`SELECT * FROM transactions WHERE id = ? AND station_id = ?`)
      .get(tx_id, req.stationId);
    if (!t) {
      return res.status(404).json(apiError('TX_NOT_FOUND', 'Transaction not found'));
    }
    db.prepare(`UPDATE transactions SET progress_litres = ? WHERE id = ?`).run(current_litres, tx_id);
    return res.json({ success: true });
  } catch (e) {
    log('error', 'progressDispense failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Progress update failed'));
  }
}
