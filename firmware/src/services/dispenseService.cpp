#include "dispenseService.h"
#include "../config/config.h"
#include "../modules/display.h"
#include "../modules/flowSensor.h"
#include "../modules/ledIndicator.h"
#include "../modules/valve.h"
#include "../services/tankSimulator.h"
#include <Arduino.h>
#include <ArduinoJson.h>
#include <esp_task_wdt.h>

void DispenseService::begin(Sim800 *modem) {
  m_modem = modem;
  m_phase = Phase::Idle;
}

bool DispenseService::start(const char *txId, float targetLitres) {
  if (m_phase != Phase::Idle || m_modem == nullptr) {
    return false;
  }
  if (targetLitres <= 0 || targetLitres > MAJISAFE_MAX_LITRES_PER_TX) {
    return false;
  }
  snprintf(m_txId, sizeof(m_txId), "%s", txId);
  m_target = targetLitres;
  FlowSensor::reset();
  Valve::openValve();
  m_t0 = millis();
  m_lastFlowMs = m_t0;
  m_lastL = 0;
  m_phase = Phase::Running;
  LedIndicator::set(LedIndicator::Mode::Dispensing);
  char l1[17];
  snprintf(l1, sizeof(l1), "STN %s", MAJISAFE_STATION_ID);
  Display::show(l1, "Dispensing...");
  return true;
}

bool DispenseService::isBusy() const {
  return m_phase != Phase::Idle;
}

void DispenseService::showLines(float cur, float target) {
  char l1[17], l2[17];
  snprintf(l1, sizeof(l1), "Now %.1f L", cur);
  snprintf(l2, sizeof(l2), "Target %.1f L", target);
  Display::show(l1, l2);
}

void DispenseService::finishConfirm(float actual) {
  Valve::closeValve();
  delay(500);
  // Update simulated tank level
  TankSimulator::onDispenseComplete(actual);
  char body[256];
  JsonDocument doc(192);
  doc["station_id"] = MAJISAFE_STATION_ID;
  doc["tx_id"] = m_txId;
  doc["actual_litres"] = actual;
  serializeJson(doc, body, sizeof(body));
  String out;
  m_modem->httpPostJson("/api/dispense/confirm", body, out);
  m_phase = Phase::Idle;
  LedIndicator::set(LedIndicator::Mode::Ready);
  Display::show("Done", "Thank you");
}

void DispenseService::finishAbort(const char *reason) {
  Valve::closeValve();
  delay(300);
  char body[320];
  JsonDocument doc(256);
  doc["station_id"] = MAJISAFE_STATION_ID;
  doc["tx_id"] = m_txId;
  doc["reason"] = reason;
  serializeJson(doc, body, sizeof(body));
  String out;
  m_modem->httpPostJson("/api/dispense/abort", body, out);
  m_phase = Phase::Idle;
  LedIndicator::set(LedIndicator::Mode::Error);
  Display::show("Error", reason);
}

void DispenseService::tick() {
  if (m_phase != Phase::Running) {
    return;
  }

  esp_task_wdt_reset();

  float L = FlowSensor::getLitres();
  if (L > m_lastL + 0.0001f) {
    m_lastFlowMs = millis();
  }
  m_lastL = L;

  static uint32_t s_lastUi = 0;
  if (millis() - s_lastUi > MAJISAFE_FLOW_SAMPLE_MS) {
    s_lastUi = millis();
    showLines(L, m_target);
  }

  uint32_t elapsed = millis() - m_t0;
  if (elapsed > MAJISAFE_VALVE_SAFETY_MS) {
    finishAbort("Safety timeout");
    return;
  }

  if (Valve::isOpen() && L < 0.05f && elapsed > MAJISAFE_NO_FLOW_ABORT_MS) {
    finishAbort("No flow / blocked");
    return;
  }

  if (L >= m_target) {
    delay(200);
    float actual = FlowSensor::getLitres();
    finishConfirm(actual);
  }
}
