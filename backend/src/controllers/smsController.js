import { v4 as uuidv4 } from 'uuid';
import { getDb } from '../models/db.js';
import { addCoins } from '../services/coinEngine.js';
import { insertLedgerTransaction } from '../services/ledger.js';
import { parsePaymentSms } from '../services/smsParser.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';

const coinPrice = () => Number(process.env.COIN_PRICE_BIF) || 10;

/**
 * Normalizes Burundi-style phone numbers for comparison.
 * @param {string} phone
 */
function normalizePhone(phone) {
  if (!phone) return '';
  let p = String(phone).replace(/\s+/g, '');
  if (p.startsWith('+')) p = p.slice(1);
  return p;
}

/**
 * Records SMS webhook payload, attempts match to pending top-up, credits coins.
 */
export function smsWebhook(req, res) {
  const secret = process.env.SMS_WEBHOOK_SECRET;
  const provided = req.headers['x-webhook-secret'] || req.body.secret;
  if (secret && provided !== secret) {
    return res.status(401).json(apiError('UNAUTHORIZED', 'Invalid webhook secret'));
  }

  const from = req.body.from || req.body.from_number;
  const message = req.body.message || req.body.text || '';
  const db = getDb();

  try {
    const { txId, amountBif } = parsePaymentSms(message);
    const norm = normalizePhone(from);

    const insertInfo = db
      .prepare(
        `INSERT INTO sms_events (from_number, message, parsed_amount, parsed_tx_id, matched_user_id, processed)
         VALUES (?, ?, ?, ?, NULL, 0)`
      )
      .run(from, message, amountBif, txId);
    const smsEventId = Number(insertInfo.lastInsertRowid);

    const user = db
      .prepare(`SELECT id FROM users WHERE phone = ? OR phone = ? OR phone = ?`)
      .get(from, `+${norm}`, norm);

    if (!user || amountBif == null || amountBif <= 0) {
      return res.json({
        success: true,
        processed: false,
        sms_event_id: smsEventId,
        reason: 'Could not match user or amount',
      });
    }

    const pending = db
      .prepare(
        `SELECT * FROM pending_topups WHERE user_id = ? AND fulfilled = 0 AND amount_bif = ? ORDER BY datetime(created_at) ASC LIMIT 1`
      )
      .get(user.id, amountBif);

    if (!pending) {
      db.prepare(`UPDATE sms_events SET matched_user_id = ? WHERE id = ?`).run(user.id, smsEventId);
      return res.json({
        success: true,
        processed: false,
        sms_event_id: smsEventId,
        reason: 'No matching pending top-up for amount',
      });
    }

    const coins = amountBif / coinPrice();
    const ledgerId = uuidv4();

    db.transaction(() => {
      addCoins(user.id, coins);
      insertLedgerTransaction(db, {
        id: ledgerId,
        user_id: user.id,
        station_id: null,
        type: 'topup',
        coins,
        volume_litres: coins,
        payment_method: 'sms',
        status: 'confirmed',
        note: txId ? `SMS TxID ${txId}` : 'SMS top-up',
      });
      db.prepare(`UPDATE pending_topups SET fulfilled = 1 WHERE id = ?`).run(pending.id);
      db.prepare(`UPDATE sms_events SET matched_user_id = ?, processed = 1 WHERE id = ?`).run(
        user.id,
        smsEventId
      );
    })();

    return res.json({
      success: true,
      processed: true,
      sms_event_id: smsEventId,
      user_id: user.id,
      coins_credited: coins,
      ledger_id: ledgerId,
    });
  } catch (e) {
    log('error', 'smsWebhook failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'SMS processing failed'));
  }
}

/**
 * Lists recent unprocessed SMS events (admin).
 */
export function smsPending(req, res) {
  try {
    const db = getDb();
    const rows = db
      .prepare(
        `SELECT * FROM sms_events WHERE processed = 0 ORDER BY datetime(received_at) DESC LIMIT 100`
      )
      .all();
    return res.json({ success: true, events: rows });
  } catch (e) {
    log('error', 'smsPending failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not load SMS events'));
  }
}
