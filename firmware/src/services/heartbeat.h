/**
 * Periodic station heartbeat to POST /api/stations/heartbeat.
 */
#ifndef MAJISAFE_HEARTBEAT_H
#define MAJISAFE_HEARTBEAT_H

#include "../modules/sim800.h"

namespace Heartbeat {
void resetTimer();
/** Call from main loop; sends at most once per MAJISAFE_HEARTBEAT_MS. */
void tick(Sim800 &modem, const char *statusText);
} // namespace Heartbeat

#endif
