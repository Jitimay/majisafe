/**
 * Extracts transaction id and amount (BIF) from a mobile-money SMS body.
 * @param {string} message Raw SMS text
 * @returns {{ txId: string|null, amountBif: number|null }}
 */
export function parsePaymentSms(message) {
  if (!message || typeof message !== 'string') {
    return { txId: null, amountBif: null };
  }
  const txMatch = message.match(/TxID\s*:\s*([A-Za-z0-9_-]+)/i);
  const amtMatch = message.match(/Amount\s*:\s*([\d.,]+)\s*BIF/i);
  const txId = txMatch ? txMatch[1].trim() : null;
  let amountBif = null;
  if (amtMatch) {
    const normalized = amtMatch[1].replace(/,/g, '');
    const n = parseFloat(normalized);
    amountBif = Number.isFinite(n) ? n : null;
  }
  return { txId, amountBif };
}
