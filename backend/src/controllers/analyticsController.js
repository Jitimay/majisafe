import { getDb } from '../models/db.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';
import { recommend } from '../services/recommendationEngine.js';

const TANK_CAPACITY_LITRES = 5000;

/**
 * GET /api/analytics/:stationId/recommendation
 */
export function getRecommendation(req, res) {
  const { stationId } = req.params;
  try {
    const db = getDb();
    const station = db
      .prepare(
        `SELECT id, tank_level, pump_1_active, pump_2_active,
                pump_1_runtime_hours, pump_2_runtime_hours
         FROM stations WHERE id = ?`
      )
      .get(stationId);

    if (!station) {
      return res.status(404).json(apiError('STATION_NOT_FOUND', 'Station not found'));
    }

    const rec = recommend({
      tank_level: station.tank_level ?? 100,
      pump_1_active: Boolean(station.pump_1_active),
      pump_2_active: Boolean(station.pump_2_active),
      pump_1_runtime_hours: station.pump_1_runtime_hours ?? 0,
      pump_2_runtime_hours: station.pump_2_runtime_hours ?? 0,
    });

    return res.json({ success: true, station_id: stationId, recommendation: rec });
  } catch (e) {
    log('error', 'getRecommendation failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not compute recommendation'));
  }
}

/**
 * GET /api/analytics/:stationId/tank-history
 * Query params: from (ISO-8601), to (ISO-8601)
 */
export function getTankHistory(req, res) {
  const { stationId } = req.params;
  const { from, to } = req.query;

  if (from && isNaN(Date.parse(from))) {
    return res.status(400).json(apiError('INVALID_DATE', 'from is not a valid ISO-8601 date'));
  }
  if (to && isNaN(Date.parse(to))) {
    return res.status(400).json(apiError('INVALID_DATE', 'to is not a valid ISO-8601 date'));
  }

  try {
    const db = getDb();
    const station = db.prepare(`SELECT id FROM stations WHERE id = ?`).get(stationId);
    if (!station) {
      return res.status(404).json(apiError('STATION_NOT_FOUND', 'Station not found'));
    }

    let sql = `SELECT id, station_id, tank_level, recorded_at FROM tank_level_history WHERE station_id = ?`;
    const params = [stationId];
    if (from) { sql += ` AND recorded_at >= ?`; params.push(new Date(from).toISOString()); }
    if (to)   { sql += ` AND recorded_at <= ?`; params.push(new Date(to).toISOString()); }
    sql += ` ORDER BY recorded_at ASC`;

    const rows = db.prepare(sql).all(...params);
    return res.json({ success: true, station_id: stationId, rows });
  } catch (e) {
    log('error', 'getTankHistory failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not fetch tank history'));
  }
}

/**
 * GET /api/analytics/:stationId/daily-usage
 * Query params: days (1–90, default 7)
 */
export function getDailyUsage(req, res) {
  const { stationId } = req.params;
  const days = parseInt(req.query.days ?? '7', 10);

  if (isNaN(days) || days < 1 || days > 90) {
    return res.status(400).json(apiError('INVALID_RANGE', 'days must be between 1 and 90'));
  }

  try {
    const db = getDb();

    // Build date series for the last N days
    const rows = db
      .prepare(
        `SELECT date(created_at) AS date, COALESCE(SUM(volume_litres), 0) AS total_litres
         FROM transactions
         WHERE station_id = ?
           AND status = 'confirmed'
           AND date(created_at) >= date('now', ? || ' days')
         GROUP BY date(created_at)`
      )
      .all(stationId, `-${days}`);

    // Fill in missing days with 0
    const byDate = {};
    for (const r of rows) byDate[r.date] = r.total_litres;

    const data = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date();
      d.setUTCDate(d.getUTCDate() - i);
      const dateStr = d.toISOString().slice(0, 10);
      data.push({ date: dateStr, total_litres: byDate[dateStr] ?? 0 });
    }

    return res.json({ success: true, station_id: stationId, days, data });
  } catch (e) {
    log('error', 'getDailyUsage failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not fetch daily usage'));
  }
}

/**
 * GET /api/analytics/:stationId/hourly-heatmap
 * Returns 7×24 matrix of average litres per hour-of-day per day-of-week (last 30 days).
 */
export function getHourlyHeatmap(req, res) {
  const { stationId } = req.params;

  try {
    const db = getDb();

    // SQLite: strftime('%w') = 0 (Sun) … 6 (Sat); we want 0=Mon … 6=Sun
    const rows = db
      .prepare(
        `SELECT
           ((CAST(strftime('%w', created_at) AS INTEGER) + 6) % 7) AS dow,
           CAST(strftime('%H', created_at) AS INTEGER) AS hour,
           SUM(volume_litres) AS total_litres,
           COUNT(DISTINCT date(created_at)) AS day_count
         FROM transactions
         WHERE station_id = ?
           AND status = 'confirmed'
           AND date(created_at) >= date('now', '-30 days')
         GROUP BY dow, hour`
      )
      .all(stationId);

    // Build 7×24 matrix initialised to 0
    const matrix = Array.from({ length: 7 }, () => new Array(24).fill(0));
    for (const r of rows) {
      if (r.day_count > 0) {
        matrix[r.dow][r.hour] = r.total_litres / r.day_count;
      }
    }

    return res.json({
      success: true,
      station_id: stationId,
      days_of_week: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      hours: Array.from({ length: 24 }, (_, i) => i),
      matrix,
    });
  } catch (e) {
    log('error', 'getHourlyHeatmap failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not fetch heatmap'));
  }
}

/**
 * GET /api/analytics/:stationId/depletion-rate
 * Returns litres_per_hour (last 24 h) and current tank_level_percent.
 */
export function getDepletionRate(req, res) {
  const { stationId } = req.params;

  try {
    const db = getDb();
    const station = db
      .prepare(`SELECT id, tank_level FROM stations WHERE id = ?`)
      .get(stationId);

    if (!station) {
      return res.status(404).json(apiError('STATION_NOT_FOUND', 'Station not found'));
    }

    const row = db
      .prepare(
        `SELECT COALESCE(SUM(volume_litres), 0) AS total_litres
         FROM transactions
         WHERE station_id = ?
           AND status = 'confirmed'
           AND created_at >= datetime('now', '-24 hours')`
      )
      .get(stationId);

    const litres_per_hour = (row?.total_litres ?? 0) / 24;

    return res.json({
      success: true,
      station_id: stationId,
      litres_per_hour,
      tank_level_percent: station.tank_level ?? 100,
    });
  } catch (e) {
    log('error', 'getDepletionRate failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not fetch depletion rate'));
  }
}

/**
 * GET /api/analytics/:stationId/time-to-empty
 */
export function getTimeToEmpty(req, res) {
  const { stationId } = req.params;

  try {
    const db = getDb();
    const station = db
      .prepare(`SELECT id, tank_level FROM stations WHERE id = ?`)
      .get(stationId);

    if (!station) {
      return res.status(404).json(apiError('STATION_NOT_FOUND', 'Station not found'));
    }

    const row = db
      .prepare(
        `SELECT COALESCE(SUM(volume_litres), 0) AS total_litres
         FROM transactions
         WHERE station_id = ?
           AND status = 'confirmed'
           AND created_at >= datetime('now', '-24 hours')`
      )
      .get(stationId);

    const litres_per_hour = (row?.total_litres ?? 0) / 24;
    const tank_level_percent = station.tank_level ?? 100;

    let estimated_minutes = null;
    if (litres_per_hour > 0) {
      estimated_minutes = Math.round(
        ((tank_level_percent / 100) * TANK_CAPACITY_LITRES) / litres_per_hour * 60
      );
    }

    return res.json({
      success: true,
      station_id: stationId,
      estimated_minutes,
      tank_level_percent,
      litres_per_hour,
    });
  } catch (e) {
    log('error', 'getTimeToEmpty failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not compute time to empty'));
  }
}
