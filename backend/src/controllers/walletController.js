import { getDb } from '../models/db.js';
import { getBalance } from '../services/coinEngine.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';

const coinPrice = () => Number(process.env.COIN_PRICE_BIF) || 10;

/**
 * Returns wallet balance and recent transactions for the current user.
 */
export function getBalanceAndRecent(req, res) {
  try {
    const coins = getBalance(req.user.id);
    const db = getDb();
    const transactions = db
      .prepare(
        `SELECT id, station_id, type, coins, volume_litres, payment_method, status, created_at
         FROM transactions WHERE user_id = ? ORDER BY datetime(created_at) DESC LIMIT 15`
      )
      .all(req.user.id);
    return res.json({ success: true, coins, transactions });
  } catch (e) {
    log('error', 'getBalanceAndRecent failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not load wallet'));
  }
}

/**
 * Creates a pending top-up record and returns payment instructions for the app.
 */
export function topup(req, res) {
  const { amount_bif, method } = req.body;
  const price = coinPrice();
  const coins = amount_bif / price;
  const db = getDb();
  try {
    db.prepare(
      `INSERT INTO pending_topups (user_id, amount_bif, method, note) VALUES (?, ?, ?, ?)`
    ).run(req.user.id, amount_bif, method || 'app', null);
    return res.json({
      success: true,
      amount_bif,
      method: method || 'app',
      coin_price_bif: price,
      equivalent_coins: coins,
      instructions: {
        sms: 'Complete payment via USSD; coins credit automatically when SMS is received.',
        bank: 'Transfer to Regideso bank account and contact support with proof.',
      },
    });
  } catch (e) {
    log('error', 'topup failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not start top-up'));
  }
}

/**
 * Returns the last 50 transactions for the current user.
 */
export function history(req, res) {
  try {
    const db = getDb();
    const rows = db
      .prepare(
        `SELECT id, station_id, type, coins, volume_litres, payment_method, status, created_at, note
         FROM transactions WHERE user_id = ? ORDER BY datetime(created_at) DESC LIMIT 50`
      )
      .all(req.user.id);
    return res.json({ success: true, transactions: rows });
  } catch (e) {
    log('error', 'history failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not load history'));
  }
}
