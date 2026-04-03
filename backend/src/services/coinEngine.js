import { getDb } from '../models/db.js';
import { log } from '../utils/logger.js';

/**
 * Loads current coin balance for a user.
 * @param {number} userId
 */
export function getBalance(userId) {
  const db = getDb();
  try {
    const row = db.prepare(`SELECT coin_balance FROM users WHERE id = ?`).get(userId);
    return row ? Number(row.coin_balance) : 0;
  } catch (e) {
    log('error', 'getBalance failed', { userId, err: String(e) });
    throw e;
  }
}

/**
 * Adds coins to a user balance. Must be called inside db.transaction() for atomicity with ledger.
 * @param {number} userId
 * @param {number} coins
 */
export function addCoins(userId, coins) {
  const db = getDb();
  if (coins <= 0) {
    const err = new Error('coins must be positive');
    err.statusCode = 400;
    err.code = 'INVALID_AMOUNT';
    throw err;
  }
  try {
    const info = db
      .prepare(`UPDATE users SET coin_balance = coin_balance + ? WHERE id = ?`)
      .run(coins, userId);
    if (info.changes !== 1) {
      const err = new Error('User not found');
      err.statusCode = 404;
      err.code = 'USER_NOT_FOUND';
      throw err;
    }
  } catch (e) {
    if (e.statusCode) throw e;
    log('error', 'addCoins failed', { userId, err: String(e) });
    throw e;
  }
}

/**
 * Deducts coins if balance is sufficient; never allows negative balance.
 * Must be called inside db.transaction().
 * @param {number} userId
 * @param {number} coins
 */
export function deductCoins(userId, coins) {
  const db = getDb();
  if (coins <= 0) {
    const err = new Error('coins must be positive');
    err.statusCode = 400;
    err.code = 'INVALID_AMOUNT';
    throw err;
  }
  try {
    const row = db.prepare(`SELECT coin_balance FROM users WHERE id = ?`).get(userId);
    if (!row) {
      const err = new Error('User not found');
      err.statusCode = 404;
      err.code = 'USER_NOT_FOUND';
      throw err;
    }
    const bal = Number(row.coin_balance);
    if (bal < coins) {
      const err = new Error(`You need ${(coins - bal).toFixed(2)} more coins`);
      err.statusCode = 402;
      err.code = 'INSUFFICIENT_COINS';
      throw err;
    }
    const info = db
      .prepare(`UPDATE users SET coin_balance = coin_balance - ? WHERE id = ? AND coin_balance >= ?`)
      .run(coins, userId, coins);
    if (info.changes !== 1) {
      const err = new Error('Concurrent balance update failed');
      err.statusCode = 409;
      err.code = 'BALANCE_CONFLICT';
      throw err;
    }
  } catch (e) {
    if (e.statusCode) throw e;
    log('error', 'deductCoins failed', { userId, err: String(e) });
    throw e;
  }
}

/**
 * Refunds coins (adds back). Must be called inside db.transaction().
 * @param {number} userId
 * @param {number} coins
 */
export function refundCoins(userId, coins) {
  addCoins(userId, coins);
}
