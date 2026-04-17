/**
 * Simulated tank level implementation using NVS for persistence.
 */
#include "tankSimulator.h"
#include "../config/config.h"
#include "../modules/pump.h"
#include <Arduino.h>
#include <nvs.h>
#include <nvs_flash.h>
#include <math.h>

static float    s_level          = 100.0f;
static uint32_t s_lastTickMs     = 0;
static uint32_t s_lastPersistMs  = 0;

void TankSimulator::begin() {
  nvs_handle_t h;
  esp_err_t err = nvs_open(MAJISAFE_NVS_NAMESPACE, NVS_READONLY, &h);
  if (err == ESP_OK) {
    uint32_t raw = 0;
    if (nvs_get_u32(h, MAJISAFE_NVS_TANK_KEY, &raw) == ESP_OK) {
      // Stored as fixed-point: level * 1000
      s_level = raw / 1000.0f;
      s_level = fmaxf(0.0f, fminf(100.0f, s_level));
    }
    nvs_close(h);
  } else {
    Serial.println("[TankSim] NVS read failed, defaulting to 100%");
    s_level = 100.0f;
  }
  s_lastTickMs    = millis();
  s_lastPersistMs = millis();
}

void TankSimulator::tick() {
  uint32_t now = millis();
  float dtSeconds = (now - s_lastTickMs) / 1000.0f;
  s_lastTickMs = now;

  if (Pump::isActive(1) || Pump::isActive(2)) {
    s_level += MAJISAFE_PUMP_FILL_RATE_PCT_PER_S * dtSeconds;
    if (s_level > 100.0f) s_level = 100.0f;
  }

  if (now - s_lastPersistMs >= MAJISAFE_NVS_PERSIST_INTERVAL_MS) {
    persist();
    s_lastPersistMs = now;
  }
}

void TankSimulator::onDispenseComplete(float actual_litres) {
  float drop = (actual_litres / MAJISAFE_TANK_CAPACITY_LITRES) * 100.0f;
  s_level -= drop;
  if (s_level < 0.0f) s_level = 0.0f;
  persist(); // persist immediately after dispense
}

float TankSimulator::getLevel() {
  return s_level;
}

void TankSimulator::persist() {
  nvs_handle_t h;
  if (nvs_open(MAJISAFE_NVS_NAMESPACE, NVS_READWRITE, &h) == ESP_OK) {
    nvs_set_u32(h, MAJISAFE_NVS_TANK_KEY, (uint32_t)(s_level * 1000.0f));
    nvs_commit(h);
    nvs_close(h);
  }
}
