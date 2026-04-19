/**
 * MajiSafe Station Firmware v1.1.0
 * Board: TTGO T-Call ESP32 + SIM800L (v1.3 / v1.4)
 *
 * ── What this firmware does ──────────────────────────────────────────────────
 *
 *  1. WATER DISPENSING (pay-first on Flutter app)
 *     User pays coins in the app → backend queues a device_command →
 *     firmware polls GET /api/dispense/device/pending every 5 s →
 *     opens valve (GPIO 25) → flow sensor counts litres →
 *     closes valve when target reached → POST /api/dispense/confirm
 *
 *  2. PUMP CONTROL (from Regideso dashboard)
 *     Operator clicks "Turn ON Pump 1" in dashboard →
 *     backend queues a pump_command →
 *     firmware polls GET /api/pumps/STN-001/pending every 10 s →
 *     sets GPIO 33 HIGH (Pump 1) or GPIO 32 HIGH (Pump 2) →
 *     POST /api/pumps/STN-001/ack → dashboard shows ON ✅
 *
 *  3. HEARTBEAT (every 60 s)
 *     POST /api/stations/heartbeat with:
 *       tank_level, pump_1_active, pump_2_active,
 *       pump_1_runtime_seconds, pump_2_runtime_seconds, status
 *     → dashboard tank gauge + pump cards update automatically
 *
 * ── Wiring ───────────────────────────────────────────────────────────────────
 *
 *  GPIO 25  → Relay CH1 → Water solenoid valve
 *  GPIO 33  → Relay CH2 → Pump 1
 *  GPIO 32  → Relay CH3 → Pump 2
 *  GPIO 35  → Flow sensor signal (YF-S201, 450 pulses/litre)
 *  GPIO 21  → LCD SDA (I²C 16×2)
 *  GPIO 22  → LCD SCL
 *  GPIO 19/18/5 → RGB LED R/G/B
 *  GPIO 26  → SIM800L RX  (ESP TX → modem)
 *  GPIO 27  → SIM800L TX  (modem TX → ESP RX)
 *  GPIO 4   → MODEM_PWKEY
 *  GPIO 5   → MODEM_RST
 *  GPIO 23  → MODEM_POWER_ON
 *
 * ── Before flashing ──────────────────────────────────────────────────────────
 *  Edit firmware/src/config/config.h:
 *    MAJISAFE_STATION_ID     — must match stations.id in the backend DB
 *    MAJISAFE_STATION_SECRET — must match stations.api_secret in the DB
 *    MAJISAFE_GPRS_APN       — your SIM card APN (e.g. "internet" for Econet)
 */

#include <Arduino.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>
#include <nvs_flash.h>

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

// ── Globals ───────────────────────────────────────────────────────────────────

static Sim800          g_modem;
static DispenseService g_dispense;
static uint32_t        s_nextDispensePoll = 0;

enum class MainState { Running, Fault };
static MainState s_state = MainState::Running;

// ── Dispense command parser ───────────────────────────────────────────────────

/**
 * Extracts tx_id and litres from the raw HTTP response of
 * GET /api/dispense/device/pending.
 * Returns true only when a non-null command is present.
 */
static bool parsePendingDispense(const String &raw, char *txId, size_t txLen, float &litres) {
  // Skip HTTP headers
  int h = raw.indexOf("\r\n\r\n");
  String body = (h >= 0) ? raw.substring(h + 4) : raw;
  body.trim();
  int o = body.indexOf('{');
  int c = body.lastIndexOf('}');
  if (o < 0 || c < o) return false;
  body = body.substring(o, c + 1);

  JsonDocument doc;
  if (deserializeJson(doc, body) != DeserializationError::Ok) return false;

  JsonObject cmd = doc["command"].as<JsonObject>();
  if (cmd.isNull()) return false;

  const char *id = cmd["tx_id"];
  if (!id || !id[0]) return false;

  float L = cmd["litres"] | 0.0f;
  if (L <= 0) return false;

  snprintf(txId, txLen, "%s", id);
  litres = L;
  return true;
}

static bool pollDispensePending(char *txId, size_t len, float &litres) {
  String raw;
  if (!g_modem.httpGetPath("/api/dispense/device/pending", raw)) return false;
  return parsePendingDispense(raw, txId, len, litres);
}

// ── setup() ──────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println("\n==========================================");
  Serial.println("  MajiSafe Station Firmware v" MAJISAFE_FIRMWARE_VERSION);
  Serial.println("  Station: " MAJISAFE_STATION_ID);
  Serial.println("  Backend: " MAJISAFE_SERVER_HOST);
  Serial.println("==========================================\n");

  // Initialise NVS (needed by TankSimulator)
  nvs_flash_init();

  // Peripheral init — all relays LOW before anything else
  Valve::begin();
  Pump::begin();          // GPIO 33 + 32 LOW
  FlowSensor::begin();
  LedIndicator::begin();
  Display::begin();

  // Watchdog: reboot if loop() stalls for > 60 s
  esp_task_wdt_init(60, true);
  esp_task_wdt_add(NULL);

  // Load persisted tank level from NVS
  TankSimulator::begin();

  // Show startup screen
  char l1[17];
  snprintf(l1, sizeof(l1), "STN %s", MAJISAFE_STATION_ID);
  Display::show(l1, "Modem init...");
  LedIndicator::set(LedIndicator::Mode::Connecting);

  // Boot modem (power-on sequence + GSM registration)
  g_dispense.begin(&g_modem);
  if (!g_modem.begin()) {
    s_state = MainState::Fault;
    Display::show("Modem FAIL", "Check wiring");
    LedIndicator::set(LedIndicator::Mode::Error);
    Serial.println("[FATAL] Modem init failed. Check wiring and SIM card.");
    return;
  }

  // Pump poller needs the modem reference
  PumpPoller::begin(&g_modem);

  LedIndicator::set(LedIndicator::Mode::Ready);
  Display::show(l1, "Ready");
  Serial.println("[MAIN] All systems ready. Entering main loop.");

  s_nextDispensePoll = millis();
  Heartbeat::resetTimer();
}

// ── loop() ───────────────────────────────────────────────────────────────────

void loop() {
  esp_task_wdt_reset();
  LedIndicator::tickBlink();

  // Hard fault — just blink error and wait for watchdog reboot
  if (s_state == MainState::Fault) {
    delay(3000);
    return;
  }

  // ── 1. Tick dispense state machine ────────────────────────────────────────
  g_dispense.tick();

  uint32_t now = millis();

  // ── 2. Tick pump poller (every 10 s) ──────────────────────────────────────
  //    Polls GET /api/pumps/STN-001/pending
  //    Executes GPIO 33 / 32 and sends ack
  PumpPoller::tick();

  // ── 3. Tick tank simulator ────────────────────────────────────────────────
  //    Increments level while a pump is active; persists to NVS every 60 s
  TankSimulator::tick();

  // ── 4. Accumulate pump runtime ────────────────────────────────────────────
  Pump::tickRuntime();

  // ── 5. Poll for water dispense commands (every 5 s, only when idle) ───────
  //    User must have paid coins in the Flutter app first.
  //    Backend queues a device_command; we pick it up here.
  if (!g_dispense.isBusy() && now >= s_nextDispensePoll) {
    s_nextDispensePoll = now + MAJISAFE_POLL_PENDING_MS;
    char txId[48];
    float litres = 0;
    if (pollDispensePending(txId, sizeof(txId), litres)) {
      Serial.printf("[DISPENSE] Starting tx=%s litres=%.1f\n", txId, litres);
      g_dispense.start(txId, litres);
    }
  }

  // ── 6. Heartbeat (every 60 s) ─────────────────────────────────────────────
  //    Sends tank_level + pump states → dashboard updates
  const char *status = g_dispense.isBusy() ? "dispensing" : "online";
  Heartbeat::tick(g_modem, status);

  // ── 7. OTA check ──────────────────────────────────────────────────────────
  OtaUpdate::check();

  delay(10);
}
