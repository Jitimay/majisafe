#include "heartbeat.h"
#include "../config/config.h"
#include "../modules/pump.h"
#include "../services/tankSimulator.h"
#include <Arduino.h>
#include <ArduinoJson.h>

static uint32_t s_last = 0;

void Heartbeat::resetTimer() {
  s_last = 0;
}

void Heartbeat::tick(Sim800 &modem, const char *statusText) {
  uint32_t now = millis();
  if (s_last != 0 && (now - s_last) < MAJISAFE_HEARTBEAT_MS) {
    return;
  }
  s_last = now;

  char body[512];
  JsonDocument doc;
  doc["station_id"]            = MAJISAFE_STATION_ID;
  doc["status"]                = statusText;
  doc["tank_level"]            = TankSimulator::getLevel();
  doc["uptime_seconds"]        = static_cast<uint32_t>(now / 1000UL);
  doc["firmware_version"]      = MAJISAFE_FIRMWARE_VERSION;
  doc["pump_1_active"]         = Pump::isActive(1);
  doc["pump_2_active"]         = Pump::isActive(2);
  doc["pump_1_runtime_seconds"] = Pump::getRuntimeSeconds(1);
  doc["pump_2_runtime_seconds"] = Pump::getRuntimeSeconds(2);

  if (serializeJson(doc, body, sizeof(body)) == 0) {
    return;
  }

  String out;
  modem.httpPostJson("/api/stations/heartbeat", body, out);
}
