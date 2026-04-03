#include "flowSensor.h"
#include "../config/config.h"
#include <Arduino.h>

static volatile uint32_t s_pulses = 0;

static void IRAM_ATTR flowIsr() {
  s_pulses++;
}

void FlowSensor::begin() {
  // GPIO35 is input-only on ESP32 (no internal pull-up); use external pull-down/up as needed.
  pinMode(MAJISAFE_FLOW_SENSOR_PIN, INPUT);
  attachInterrupt(digitalPinToInterrupt(MAJISAFE_FLOW_SENSOR_PIN), flowIsr, RISING);
}

void FlowSensor::reset() {
  noInterrupts();
  s_pulses = 0;
  interrupts();
}

float FlowSensor::getLitres() {
  uint32_t p;
  noInterrupts();
  p = s_pulses;
  interrupts();
  return static_cast<float>(p) / MAJISAFE_PULSES_PER_LITRE;
}
