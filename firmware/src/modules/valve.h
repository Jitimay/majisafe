/**
 * Solenoid / relay driving the water valve. Defaults CLOSED (LOW) at boot.
 */
#ifndef MAJISAFE_VALVE_H
#define MAJISAFE_VALVE_H

namespace Valve {
void begin();
void openValve();
void closeValve();
bool isOpen();
} // namespace Valve

#endif
