import { getDb } from '../models/db.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';

/**
 * Lists all stations with public fields (no api_secret).
 */
export function listStations(req, res) {
  try {
    const db = getDb();
    const rows = db
      .prepare(
        `SELECT id, name, location, status, tank_level, last_seen, sim_number FROM stations ORDER BY id`
      )
      .all();
    const online = rows.filter((r) => r.status === 'online' || r.status === 'dispensing').length;
    return res.json({ success: true, stations: rows, active_count: online });
  } catch (e) {
    log('error', 'listStations failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not list stations'));
  }
}

/**
 * Returns one station and recent related transactions.
 */
export function getStation(req, res) {
  const { id } = req.params;
  try {
    const db = getDb();
    const station = db
      .prepare(
        `SELECT id, name, location, status, tank_level, last_seen, sim_number FROM stations WHERE id = ?`
      )
      .get(id);
    if (!station) {
      return res.status(404).json(apiError('STATION_NOT_FOUND', 'Station not found'));
    }
    const activity = db
      .prepare(
        `SELECT id, user_id, type, coins, volume_litres, status, created_at FROM transactions WHERE station_id = ? ORDER BY datetime(created_at) DESC LIMIT 20`
      )
      .all(id);
    return res.json({ success: true, station, recent_activity: activity });
  } catch (e) {
    log('error', 'getStation failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not load station'));
  }
}

/**
 * Heartbeat from firmware: updates presence and telemetry.
 */
export function heartbeat(req, res) {
  const { station_id, status, tank_level, uptime_seconds, firmware_version } = req.body;
  try {
    const db = getDb();
    const row = db.prepare(`SELECT id FROM stations WHERE id = ?`).get(station_id);
    if (!row) {
      return res.status(404).json(apiError('STATION_NOT_FOUND', 'Station not found'));
    }
    if (req.stationId && station_id !== req.stationId) {
      return res.status(400).json(apiError('STATION_MISMATCH', 'Station mismatch'));
    }
    const st = status || 'online';
    db.prepare(
      `UPDATE stations SET status = ?, tank_level = COALESCE(?, tank_level), last_seen = datetime('now') WHERE id = ?`
    ).run(st, tank_level ?? null, station_id);
    return res.json({
      success: true,
      station_id,
      status: st,
      uptime_seconds: uptime_seconds ?? null,
      firmware_version: firmware_version ?? null,
    });
  } catch (e) {
    log('error', 'heartbeat failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Heartbeat failed'));
  }
}
