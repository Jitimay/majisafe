/**
 * Flow meter pulse counter (ISR) and litre readout.
 */
#ifndef MAJISAFE_FLOW_SENSOR_H
#define MAJISAFE_FLOW_SENSOR_H

namespace FlowSensor {
void begin();
void reset();
float getLitres();
} // namespace FlowSensor

#endif
