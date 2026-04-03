import { log } from '../utils/logger.js';

/**
 * Sleeps for a given number of milliseconds.
 * @param {number} ms
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Sends a JSON dispense command to the station HTTP endpoint with retries.
 * Returns true if any attempt returned HTTP 2xx.
 * @param {string|null|undefined} url Full URL (e.g. http://host/dispense)
 * @param {{ tx_id: string, litres: number, timeout_seconds: number }} body
 */
export async function sendDispenseHttp(url, body) {
  if (!url || !String(url).trim()) {
    return false;
  }
  const timeoutMs = Number(process.env.DISPATCH_HTTP_TIMEOUT_MS) || 10000;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const ac = new AbortController();
      const timer = setTimeout(() => ac.abort(), timeoutMs);
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tx_id: body.tx_id,
          litres: body.litres,
          timeout_seconds: body.timeout_seconds ?? 60,
        }),
        signal: ac.signal,
      });
      clearTimeout(timer);
      if (res.ok) {
        log('info', 'dispense HTTP ok', { url, tx_id: body.tx_id, attempt });
        return true;
      }
      log('warn', 'dispense HTTP non-ok', { status: res.status, attempt });
    } catch (e) {
      log('warn', 'dispense HTTP attempt failed', { attempt, err: String(e) });
    }
    if (attempt < 3) {
      await sleep(5000);
    }
  }
  return false;
}
