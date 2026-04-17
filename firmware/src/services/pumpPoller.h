/**
 * Polls the backend for pending pump commands and executes them via GPIO.
 */
#ifndef MAJISAFE_PUMP_POLLER_H
#define MAJISAFE_PUMP_POLLER_H

#include "../modules/sim800.h"

namespace PumpPoller {
  /** Initialise with modem reference. */
  void begin(Sim800 *modem);

  /** Called every loop() — polls every MAJISAFE_PUMP_POLL_MS ms. */
  void tick();
}

#endif
