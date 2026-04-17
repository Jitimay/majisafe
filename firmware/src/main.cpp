/**
 * MajiSafe station firmware: poll pending commands, dispense, heartbeat.
 * Board: LilyGO T-Call ESP32 + SIM800L (see README wiring / config).
 */
#include <Arduino.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>

#include "config/config.h"
#include "modules/display.h"
#include "modules/flowSensor.h"
#include "modules/ledIndicator.h"
#include "modules/pump.h"
#include "modules/sim800.h"
#include "modules/valve.h"
#include "services/dispenseService.h"
#include "services/heartbeat.h"
#include "services/otaUpdate.h"
#include "services/pumpPoller.h"
#include "services/tankSimulator.h"

static Sim800 g_modem;
static DispenseService g_dispense;
static uint32_t s_nextPoll = 0;

enum class MainState { Running, Fault };
static MainState s_state = MainState::Running;

/** Parses GET /device/pending JSON body for a non-null command. */
static bool parsePendingCommand(const String &raw, char *txId, size_t txLen, float &litres) {
  int h = raw.indexOf("\r\n\r\n");
  if (h < 0) {
    return false;
  }
  String body = raw.substring(h + 4);
  body.trim();
  int o = body.indexOf('{');
  int c = body.lastIndexOf('}');
  if (o < 0 || c < o) {
    return false;
  }
  body = body.substring(o, c + 1);
  JsonDocument doc(512);
  DeserializationError err = deserializeJson(doc, body);
  if (err) {
    return false;
  }
  JsonObject cmd = doc["command"].as<JsonObject>();
  if (cmd.isNull()) {
    return false;
  }
  const char *id = cmd["tx_id"];
  if (!id || !id[0]) {
    return false;
  }
  float L = cmd["litres"] | 0.0f;
  if (L <= 0) {
    return false;
  }
  snprintf(txId, txLen, "%s", id);
  litres = L;
  return true;
}

static bool pollPending(char *txId, size_t len, float &litres) {
  String raw;
  if (!g_modem.httpGetPath("/api/dispense/device/pending", raw)) {
    return false;
  }
  return parsePendingCommand(raw, txId, len, litres);
}

void setup() {
  Serial.begin(115200);
  delay(800);

  Valve::begin();
  FlowSensor::begin();
  LedIndicator::begin();
  Display::begin();
  Pump::begin();
  TankSimulator::begin();

  esp_task_wdt_init(60, true);
  esp_task_wdt_add(NULL);

  char l1[17];
  snprintf(l1, sizeof(l1), "STN %s", MAJISAFE_STATION_ID);
  Display::show(l1, "Modem...");
  LedIndicator::set(LedIndicator::Mode::Connecting);

  g_dispense.begin(&g_modem);
  if (!g_modem.begin()) {
    s_state = MainState::Fault;
    Display::show("Modem", "AT fail");
    LedIndicator::set(LedIndicator::Mode::Error);
    return;
  }

  PumpPoller::begin(&g_modem);
  LedIndicator::set(LedIndicator::Mode::Ready);
  Display::show(l1, "Ready");
  s_nextPoll = millis();
  Heartbeat::resetTimer();
}

void loop() {
  esp_task_wdt_reset();
  LedIndicator::tickBlink();

  if (s_state == MainState::Fault) {
    delay(3000);
    return;
  }

  g_dispense.tick();

  uint32_t now = millis();

  PumpPoller::tick();
  TankSimulator::tick();
  Pump::tickRuntime();

  if (!g_dispense.isBusy()) {
    if (now >= s_nextPoll) {
      s_nextPoll = now + MAJISAFE_POLL_PENDING_MS;
      char txId[48];
      float litres = 0;
      if (pollPending(txId, sizeof(txId), litres)) {
        g_dispense.start(txId, litres);
      }
    }
  }

  const char *st = g_dispense.isBusy() ? "dispensing" : "online";
  Heartbeat::tick(g_modem, st);
  OtaUpdate::check();

  delay(10);
}
