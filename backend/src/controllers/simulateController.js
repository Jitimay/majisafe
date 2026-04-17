import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../models/db.js';
import { addCoins } from '../services/coinEngine.js';
import { insertLedgerTransaction } from '../services/ledger.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';

const coinPrice = () => Number(process.env.COIN_PRICE_BIF) || 10;

/**
 * Simulates a mobile-money payment and instantly credits coins.
 * Only available when NODE_ENV !== 'production' OR SIMULATE_ENABLED=true.
 *
 * POST /api/simulate/topup
 * Body: { amount_bif: number, method?: string, note?: string }
 */
export function simulateTopup(req, res) {
  const { amount_bif, method, note } = req.body;
  const userId = req.user.id;
  const db = getDb();

  try {
    const price = coinPrice();
    const coins = amount_bif / price;
    const txId = uuidv4();
    const simId = uuidv4();
    const paymentRef = `SIM-${simId.slice(0, 8).toUpperCase()}`;

    db.transaction(() => {
      // Record the simulated payment
      db.prepare(
        `INSERT INTO simulated_payments
           (id, user_id, amount_bif, coins, payment_ref, method, note, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'completed')`
      ).run(simId, userId, amount_bif, coins, paymentRef, method || 'simulate', note || null);

      // Credit coins
      addCoins(userId, coins);

      // Write tamper-evident ledger entry
      insertLedgerTransaction(db, {
        id: txId,
        user_id: userId,
        station_id: null,
        type: 'topup',
        coins,
        volume_litres: null,
        payment_method: method || 'simulate',
        status: 'confirmed',
        note: note || `Simulated payment ${paymentRef} — ${amount_bif} BIF`,
      });
    })();

    log('info', 'simulated topup', { userId, amount_bif, coins, paymentRef });

    return res.json({
      success: true,
      payment_ref: paymentRef,
      amount_bif,
      coins_credited: coins,
      coin_price_bif: price,
      tx_id: txId,
      message: `${coins.toFixed(1)} coins added to your wallet`,
    });
  } catch (e) {
    if (e.statusCode) {
      return res.status(e.statusCode).json(apiError(e.code, e.message));
    }
    log('error', 'simulateTopup failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Simulation failed'));
  }
}

/**
 * Returns the last 20 simulated payments for the current user.
 * GET /api/simulate/history
 */
export function simulateHistory(req, res) {
  const db = getDb();
  try {
    const rows = db
      .prepare(
        `SELECT id, amount_bif, coins, payment_ref, method, note, status, created_at
         FROM simulated_payments WHERE user_id = ?
         ORDER BY datetime(created_at) DESC LIMIT 20`
      )
      .all(req.user.id);
    return res.json({ success: true, payments: rows });
  } catch (e) {
    log('error', 'simulateHistory failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not load history'));
  }
}

/**
 * Admin: list all simulated payments across all users.
 * GET /api/simulate/admin/all
 */
export function simulateAdminAll(req, res) {
  const db = getDb();
  try {
    const rows = db
      .prepare(
        `SELECT sp.*, u.phone, u.name
         FROM simulated_payments sp
         JOIN users u ON u.id = sp.user_id
         ORDER BY datetime(sp.created_at) DESC LIMIT 100`
      )
      .all();
    return res.json({ success: true, payments: rows });
  } catch (e) {
    log('error', 'simulateAdminAll failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not load payments'));
  }
}
