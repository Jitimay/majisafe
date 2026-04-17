/**
 * Pure-JS rule-based recommendation engine for pump control.
 * No database access — receives a plain station object, returns a recommendation.
 */

const TANK_LOW_THRESHOLD  = 30; // %
const TANK_HIGH_THRESHOLD = 80; // %

/**
 * @param {object} station
 * @param {number}  station.tank_level
 * @param {boolean} station.pump_1_active
 * @param {boolean} station.pump_2_active
 * @param {number}  station.pump_1_runtime_hours
 * @param {number}  station.pump_2_runtime_hours
 * @returns {{ action: string, pump_number: number|null, reason: string, urgency: string }}
 */
export function recommend(station) {
  try {
    const {
      tank_level,
      pump_1_active,
      pump_2_active,
      pump_1_runtime_hours,
      pump_2_runtime_hours,
    } = station;

    const anyPumpActive = pump_1_active || pump_2_active;

    if (tank_level < TANK_LOW_THRESHOLD) {
      if (!anyPumpActive) {
        // Pick pump with fewer runtime hours; default to pump 1 on tie
        const pumpNum = pump_1_runtime_hours <= pump_2_runtime_hours ? 1 : 2;
        const thisHours  = pumpNum === 1 ? pump_1_runtime_hours : pump_2_runtime_hours;
        const otherHours = pumpNum === 1 ? pump_2_runtime_hours : pump_1_runtime_hours;
        const reason = `Tank at ${Number(tank_level).toFixed(0)}% — below ${TANK_LOW_THRESHOLD}% threshold. Pump ${pumpNum} has fewer runtime hours (${Number(thisHours).toFixed(1)}h vs ${Number(otherHours).toFixed(1)}h).`;
        return {
          action: `activate_pump_${pumpNum}`,
          pump_number: pumpNum,
          reason: reason.slice(0, 120),
          urgency: 'high',
        };
      }
      // One pump already running — no additional action needed
      return {
        action: 'no_action',
        pump_number: null,
        reason: `Tank at ${Number(tank_level).toFixed(0)}% but a pump is already active. Monitoring.`.slice(0, 120),
        urgency: 'low',
      };
    }

    if (tank_level > TANK_HIGH_THRESHOLD && anyPumpActive) {
      const activePump = pump_1_active ? 1 : 2;
      return {
        action: 'deactivate_pump',
        pump_number: activePump,
        reason: `Tank at ${Number(tank_level).toFixed(0)}% — above ${TANK_HIGH_THRESHOLD}% threshold. Deactivate Pump ${activePump}.`.slice(0, 120),
        urgency: 'medium',
      };
    }

    return {
      action: 'no_action',
      pump_number: null,
      reason: `Tank at ${Number(tank_level).toFixed(0)}% — within normal range (${TANK_LOW_THRESHOLD}–${TANK_HIGH_THRESHOLD}%). No action needed.`.slice(0, 120),
      urgency: 'low',
    };
  } catch (err) {
    // Never throw — return safe default
    return {
      action: 'no_action',
      pump_number: null,
      reason: 'Unable to compute recommendation.',
      urgency: 'low',
    };
  }
}
