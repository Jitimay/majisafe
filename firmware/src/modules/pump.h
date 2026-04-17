/**
 * Pump relay control module.
 * GPIO 33 = Pump 1 relay, GPIO 32 = Pump 2 relay.
 */
#ifndef MAJISAFE_PUMP_H
#define MAJISAFE_PUMP_H

#include <Arduino.h>

namespace Pump {
  /** Initialise GPIO pins (both LOW / off). */
  void  begin();

  /** Set relay HIGH to activate pump (1 or 2). */
  void  activate(uint8_t pumpNumber);

  /** Set relay LOW to deactivate pump (1 or 2). */
  void  deactivate(uint8_t pumpNumber);

  /** Returns true if the pump relay is currently HIGH. */
  bool  isActive(uint8_t pumpNumber);

  /** Returns accumulated runtime in seconds for the pump. */
  float getRuntimeSeconds(uint8_t pumpNumber);

  /** Called every loop() iteration to accumulate runtime. */
  void  tickRuntime();
}

#endif
