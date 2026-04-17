/**
 * Pump poller: polls /api/pumps/:stationId/pending every 10 s,
 * executes GPIO command, sends ack (with retry on GPRS failure).
 */
#include "pumpPoller.h"
#include "../config/config.h"
#include "../modules/pump.h"
#include <Arduino.h>
#include <ArduinoJson.h>

static Sim800  *s_modem       = nullptr;
static uint32_t s_nextPollMs  = 0;

// Retry buffer for failed acks
static bool s_pendingAck          = false;
static int  s_pendingAckCommandId = -1;
static bool s_pendingAckPump1     = false;
static bool s_pendingAckPump2     = false;

static bool sendAck(int commandId, bool p1, bool p2) {
  char body[128];
  JsonDocument doc;
  doc["command_id"]    = commandId;
  doc["pump_status_1"] = p1;
  doc["pump_status_2"] = p2;
  serializeJson(doc, body, sizeof(body));
  String out;
  return s_modem->httpPostJson(
    "/api/pumps/" MAJISAFE_STATION_ID "/ack", body, out);
}

static bool parsePumpCommand(const String &raw, int &commandId, int &pumpNumber, char *action, size_t actionLen) {
  int h = raw.indexOf("\r\n\r\n");
  String body = (h >= 0) ? raw.substring(h + 4) : raw;
  body.trim();
  int o = body.indexOf('{');
  int c = body.lastIndexOf('}');
  if (o < 0 || c < o) return false;
  body = body.substring(o, c + 1);

  JsonDocument doc;
  if (deserializeJson(doc, body) != DeserializationError::Ok) return false;

  if (doc["command"].isNull()) return false;
  JsonObject cmd = doc["command"].as<JsonObject>();
  if (cmd.isNull()) return false;

  commandId  = cmd["id"]          | -1;
  pumpNumber = cmd["pump_number"] | -1;
  const char *act = cmd["action"];
  if (!act || commandId < 0 || (pumpNumber != 1 && pumpNumber != 2)) return false;
  snprintf(action, actionLen, "%s", act);
  return true;
}

void PumpPoller::begin(Sim800 *modem) {
  s_modem      = modem;
  s_nextPollMs = millis() + MAJISAFE_PUMP_POLL_MS;
}

void PumpPoller::tick() {
  if (!s_modem) return;
  uint32_t now = millis();

  // Retry pending ack first
  if (s_pendingAck) {
    if (sendAck(s_pendingAckCommandId, s_pendingAckPump1, s_pendingAckPump2)) {
      s_pendingAck = false;
    }
    return;
  }

  if (now < s_nextPollMs) return;
  s_nextPollMs = now + MAJISAFE_PUMP_POLL_MS;

  String raw;
  if (!s_modem->httpGetPath("/api/pumps/" MAJISAFE_STATION_ID "/pending", raw)) {
    return; // GPRS unavailable; retry next cycle
  }

  int  commandId  = -1;
  int  pumpNumber = -1;
  char action[16] = {};
  if (!parsePumpCommand(raw, commandId, pumpNumber, action, sizeof(action))) {
    return; // null command or parse error
  }

  // Execute GPIO
  if (pumpNumber == 1) {
    if (strcmp(action, "activate") == 0) Pump::activate(1);
    else                                  Pump::deactivate(1);
  } else if (pumpNumber == 2) {
    if (strcmp(action, "activate") == 0) Pump::activate(2);
    else                                  Pump::deactivate(2);
  }

  // Send ack
  bool p1 = Pump::isActive(1);
  bool p2 = Pump::isActive(2);
  if (!sendAck(commandId, p1, p2)) {
    // Store for retry
    s_pendingAck          = true;
    s_pendingAckCommandId = commandId;
    s_pendingAckPump1     = p1;
    s_pendingAckPump2     = p2;
  }
}
