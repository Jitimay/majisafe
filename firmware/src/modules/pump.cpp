/**
 * Pump relay control implementation.
 */
#include "pump.h"
#include "../config/config.h"
#include <Arduino.h>

static bool    s_active[3]         = {false, false, false}; // index 1 and 2 used
static float   s_runtimeSeconds[3] = {0.0f, 0.0f, 0.0f};
static uint32_t s_lastTickMs       = 0;

static uint8_t pinForPump(uint8_t n) {
  return (n == 1) ? MAJISAFE_PUMP_1_PIN : MAJISAFE_PUMP_2_PIN;
}

void Pump::begin() {
  pinMode(MAJISAFE_PUMP_1_PIN, OUTPUT);
  pinMode(MAJISAFE_PUMP_2_PIN, OUTPUT);
  digitalWrite(MAJISAFE_PUMP_1_PIN, LOW);
  digitalWrite(MAJISAFE_PUMP_2_PIN, LOW);
  s_active[1] = false;
  s_active[2] = false;
  s_lastTickMs = millis();
}

void Pump::activate(uint8_t pumpNumber) {
  if (pumpNumber < 1 || pumpNumber > 2) return;
  digitalWrite(pinForPump(pumpNumber), HIGH);
  s_active[pumpNumber] = true;
}

void Pump::deactivate(uint8_t pumpNumber) {
  if (pumpNumber < 1 || pumpNumber > 2) return;
  digitalWrite(pinForPump(pumpNumber), LOW);
  s_active[pumpNumber] = false;
}

bool Pump::isActive(uint8_t pumpNumber) {
  if (pumpNumber < 1 || pumpNumber > 2) return false;
  return s_active[pumpNumber];
}

float Pump::getRuntimeSeconds(uint8_t pumpNumber) {
  if (pumpNumber < 1 || pumpNumber > 2) return 0.0f;
  return s_runtimeSeconds[pumpNumber];
}

void Pump::tickRuntime() {
  uint32_t now = millis();
  float dt = (now - s_lastTickMs) / 1000.0f;
  s_lastTickMs = now;
  if (s_active[1]) s_runtimeSeconds[1] += dt;
  if (s_active[2]) s_runtimeSeconds[2] += dt;
}
