import { getDb } from '../models/db.js';
import { apiError } from '../utils/errors.js';
import { log } from '../utils/logger.js';

/**
 * POST /api/pumps/:stationId/command
 * Admin only — inserts a pump command record.
 */
export function sendPumpCommand(req, res) {
  const { stationId } = req.params;
  const { pump_number, action } = req.body;

  if (pump_number !== 1 && pump_number !== 2) {
    return res.status(400).json(apiError('INVALID_PUMP', 'pump_number must be 1 or 2'));
  }
  if (action !== 'activate' && action !== 'deactivate') {
    return res.status(400).json(apiError('INVALID_ACTION', 'action must be activate or deactivate'));
  }

  try {
    const db = getDb();
    const station = db.prepare(`SELECT id FROM stations WHERE id = ?`).get(stationId);
    if (!station) {
      return res.status(404).json(apiError('STATION_NOT_FOUND', 'Station not found'));
    }

    const result = db
      .prepare(
        `INSERT INTO pump_commands (station_id, pump_number, action, status)
         VALUES (?, ?, ?, 'pending')`
      )
      .run(stationId, pump_number, action);

    const row = db
      .prepare(`SELECT id, station_id, pump_number, action, status, created_at FROM pump_commands WHERE id = ?`)
      .get(result.lastInsertRowid);

    return res.json({
      success: true,
      id: row.id,
      station_id: row.station_id,
      pump_number: row.pump_number,
      action: row.action,
      status: row.status,
      created_at: row.created_at,
    });
  } catch (e) {
    log('error', 'sendPumpCommand failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not create pump command'));
  }
}

/**
 * GET /api/pumps/:stationId/pending
 * Station auth — returns oldest pending command and marks it sent.
 */
export function getPendingPumpCommand(req, res) {
  const { stationId } = req.params;

  try {
    const db = getDb();

    const command = db
      .prepare(
        `SELECT id, pump_number, action FROM pump_commands
         WHERE station_id = ? AND status = 'pending'
         ORDER BY id ASC LIMIT 1`
      )
      .get(stationId);

    if (!command) {
      return res.json({ success: true, command: null });
    }

    db.prepare(`UPDATE pump_commands SET status = 'sent' WHERE id = ?`).run(command.id);

    return res.json({
      success: true,
      command: {
        id: command.id,
        pump_number: command.pump_number,
        action: command.action,
      },
    });
  } catch (e) {
    log('error', 'getPendingPumpCommand failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not fetch pending command'));
  }
}

/**
 * POST /api/pumps/:stationId/ack
 * Station auth — acknowledges a command and updates pump status on station.
 */
export function ackPumpCommand(req, res) {
  const { stationId } = req.params;
  const { command_id, pump_status_1, pump_status_2 } = req.body;

  try {
    const db = getDb();

    const command = db
      .prepare(`SELECT id, station_id FROM pump_commands WHERE id = ?`)
      .get(command_id);

    if (!command || command.station_id !== stationId) {
      return res.status(404).json(apiError('COMMAND_NOT_FOUND', 'Command not found'));
    }

    const now = new Date().toISOString();
    db.prepare(
      `UPDATE pump_commands SET status = 'acknowledged', acknowledged_at = ? WHERE id = ?`
    ).run(now, command_id);

    db.prepare(
      `UPDATE stations SET pump_1_active = ?, pump_2_active = ? WHERE id = ?`
    ).run(pump_status_1 ? 1 : 0, pump_status_2 ? 1 : 0, stationId);

    return res.json({
      success: true,
      command_id,
      acknowledged_at: now,
    });
  } catch (e) {
    log('error', 'ackPumpCommand failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not acknowledge command'));
  }
}

/**
 * GET /api/pumps/:stationId/status
 * Admin only — returns current pump status for a station.
 */
export function getPumpStatus(req, res) {
  const { stationId } = req.params;

  try {
    const db = getDb();
    const station = db
      .prepare(
        `SELECT id, pump_1_active, pump_2_active, pump_1_runtime_hours, pump_2_runtime_hours
         FROM stations WHERE id = ?`
      )
      .get(stationId);

    if (!station) {
      return res.status(404).json(apiError('STATION_NOT_FOUND', 'Station not found'));
    }

    return res.json({
      success: true,
      station_id: station.id,
      pump_1_active: Boolean(station.pump_1_active),
      pump_2_active: Boolean(station.pump_2_active),
      pump_1_runtime_hours: station.pump_1_runtime_hours ?? 0,
      pump_2_runtime_hours: station.pump_2_runtime_hours ?? 0,
    });
  } catch (e) {
    log('error', 'getPumpStatus failed', { err: String(e) });
    return res.status(500).json(apiError('INTERNAL_ERROR', 'Could not fetch pump status'));
  }
}
