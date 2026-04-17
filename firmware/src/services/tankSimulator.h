/**
 * Simulated tank level service.
 * Persists level to NVS; fills while pump active, drains on dispense.
 */
#ifndef MAJISAFE_TANK_SIMULATOR_H
#define MAJISAFE_TANK_SIMULATOR_H

#include <Arduino.h>

namespace TankSimulator {
  /** Load level from NVS (defaults to 100.0 on first boot or read failure). */
  void  begin();

  /** Called every loop() — increments level while a pump is active. */
  void  tick();

  /** Called after a confirmed dispense to decrement level. */
  void  onDispenseComplete(float actual_litres);

  /** Returns current tank level [0.0, 100.0]. */
  float getLevel();

  /** Write current level to NVS immediately. */
  void  persist();
}

#endif
