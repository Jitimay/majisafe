import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../models/db.js';
import { deductCoins } from '../services/coinEngine.js';
import { insertLedgerTransaction } from '../services/ledger.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';

// 1 coin = 1 kWh (same ratio as water: 1 coin = 1 litre)
const COINS_PER_KWH = 1;

/**
 * Generates a simple 20-digit electricity token (demo).
 * In production this would call the actual REGIDESO token API.
 */
function generateToken() {
  const digits = Array.from({ length: 20 }, () => Math.floor(Math.random() * 10)).join('');
  return `${digits.slice(0, 4)}-${digits.slice(4, 8)}-${digits.slice(8, 12)}-${digits.slice(12, 16)}-${digits.slice(16)}`;
}

/**
 * POST /api/electricity/buy
 * Deducts coins, generates token, records order + ledger entry.
 */
export function buyElectricity(req, res) {
  const { meter_number, coins } = req.body;
  const userId = req.user.id;
  const db = getDb();

  try {
    const kwh = coins / COINS_PER_KWH;
    const orderId = uuidv4();
    const token = generateToken();

    db.transaction(() => {
      deductCoins(userId, coins);
      insertLedgerTransaction(db, {
        id: orderId,
        user_id: userId,
        station_id: null,
        type: 'electricity',
        coins,
        volume_litres: null,
        payment_method: 'app',
        status: 'confirmed',
        note: `Electricity ${kwh} kWh for meter ${meter_number}`,
      });
      db.prepare(
        `INSERT INTO electricity_orders (id, user_id, meter_number, coins, kwh, token, status)
         VALUES (?, ?, ?, ?, ?, ?, 'confirmed')`
      ).run(orderId, userId, meter_number, coins, kwh, token);
    })();

    log('info', 'electricity purchased', { userId, meter_number, coins, kwh, orderId });

    return res.json({
      success: true,
      order_id: orderId,
      meter_number,
      coins_spent: coins,
      kwh,
      token,
      status: 'confirmed',
    });
  } catch (e) {
    if (e.statusCode) {
      return res.status(e.statusCode).json(apiError(e.code, e.message));
    }
    log('error', 'buyElectricity failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Electricity purchase failed'));
  }
}

/**
 * GET /api/electricity/history
 * Returns last 20 electricity orders for the current user.
 */
export function electricityHistory(req, res) {
  const db = getDb();
  try {
    const rows = db
      .prepare(
        `SELECT id, meter_number, coins, kwh, token, status, created_at
         FROM electricity_orders WHERE user_id = ?
         ORDER BY datetime(created_at) DESC LIMIT 20`
      )
      .all(req.user.id);
    return res.json({ success: true, orders: rows });
  } catch (e) {
    log('error', 'electricityHistory failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not load history'));
  }
}
