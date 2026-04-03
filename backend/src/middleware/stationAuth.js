import { getDb } from '../models/db.js';
import { apiError } from '../utils/errors.js';

/**
 * Validates X-Station-Id and X-Station-Secret against the stations table.
 */
export function stationAuthMiddleware(req, res, next) {
  const stationId = req.headers['x-station-id'] || req.headers['x-majisafe-station'];
  const secret = req.headers['x-station-secret'] || req.headers['x-majisafe-secret'];
  if (!stationId || !secret) {
    return res.status(401).json(apiError('UNAUTHORIZED', 'Station credentials required'));
  }
  try {
    const db = getDb();
    const row = db
      .prepare(`SELECT id, api_secret FROM stations WHERE id = ?`)
      .get(String(stationId));
    if (!row || row.api_secret !== String(secret)) {
      return res.status(401).json(apiError('UNAUTHORIZED', 'Invalid station credentials'));
    }
    req.stationId = row.id;
    return next();
  } catch {
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Station auth failed'));
  }
}
