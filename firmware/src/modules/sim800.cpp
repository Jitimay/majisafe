/**
 * SIM800L driver for TTGO T-Call v1.3/v1.4.
 *
 * Power-on sequence uses MODEM_PWKEY (GPIO4), MODEM_RST (GPIO5),
 * MODEM_POWER_ON (GPIO23) — same as the reference Pesa-AI sketch.
 *
 * HTTP is plain TCP/HTTP 1.1 because SIM800L does not support TLS
 * to arbitrary hosts. Station auth headers are injected on every request.
 */
#include "sim800.h"
#include "../config/config.h"
#include <HardwareSerial.h>

static HardwareSerial Modem(1);   // UART1

// ── Low-level AT helpers ──────────────────────────────────────────────────────

void Sim800::flushIn() {
  while (Modem.available()) Modem.read();
}

/**
 * Send an AT command and collect the response until OK/ERROR or timeout.
 */
String Sim800::atLine(const char *cmd, uint32_t timeoutMs) {
  flushIn();
  Modem.print(cmd);
  Modem.print("\r\n");
  uint32_t t0 = millis();
  String acc;
  while (millis() - t0 < timeoutMs) {
    while (Modem.available()) acc += static_cast<char>(Modem.read());
    if (acc.indexOf("OK")    >= 0) break;
    if (acc.indexOf("ERROR") >= 0) break;
    delay(10);
  }
  return acc;
}

// ── Power-on sequence (T-Call v1.3 / v1.4) ───────────────────────────────────

static void powerOnModem() {
  pinMode(MAJISAFE_MODEM_PWKEY,    OUTPUT);
  pinMode(MAJISAFE_MODEM_RST,      OUTPUT);
  pinMode(MAJISAFE_MODEM_POWER_ON, OUTPUT);

  digitalWrite(MAJISAFE_MODEM_PWKEY,    LOW);
  digitalWrite(MAJISAFE_MODEM_RST,      HIGH);
  digitalWrite(MAJISAFE_MODEM_POWER_ON, HIGH);

  Serial.println("[MODEM] Powering up (T-Call sequence)...");
  delay(3000);   // wait for SIM800 to boot
}

// ── Public API ────────────────────────────────────────────────────────────────

bool Sim800::begin() {
  powerOnModem();

  // Open UART at 115200 first (matches your reference sketch), then drop to
  // 9600 for reliable TCP transfers on long cables / noisy lines.
  Modem.begin(115200, SERIAL_8N1, MAJISAFE_MODEM_RX, MAJISAFE_MODEM_TX);
  delay(3000);

  // Probe
  String r = atLine("AT", 3000);
  Serial.println("[AT]  " + r);
  if (r.indexOf("OK") < 0) {
    // Try 9600 in case modem already autobauded down
    Modem.end();
    Modem.begin(9600, SERIAL_8N1, MAJISAFE_MODEM_RX, MAJISAFE_MODEM_TX);
    delay(1000);
    r = atLine("AT", 3000);
    if (r.indexOf("OK") < 0) return false;
  }

  atLine("ATE0",       2000);   // echo off
  atLine("AT+CFUN=1",  5000);   // full functionality
  atLine("AT+CNMP=13", 2000);   // GSM only (faster registration in Burundi)
  atLine("AT+CSCS=\"GSM\"", 1000); // GSM character set

  // Check SIM
  Serial.println("[SIM] " + atLine("AT+CPIN?", 3000));

  // Wait for GSM network registration
  Serial.print("[MODEM] Waiting for GSM network");
  for (int i = 0; i < 40; i++) {
    atLine("AT+CREG?", 500);
    String resp = atLine("AT+CREG?", 800);
    Serial.print(".");
    if (resp.indexOf(",1") >= 0 || resp.indexOf(",5") >= 0) {
      Serial.println(" OK");
      break;
    }
    delay(1500);
  }

  Serial.println("[OPR] " + atLine("AT+COPS?", 3000));
  Serial.println("[SIG] " + atLine("AT+CSQ",   2000));
  Serial.println("[MODEM] READY");
  return true;
}

bool Sim800::ensureGprs() {
  atLine("AT+CGATT=1", 5000);
  char cstt[96];
  snprintf(cstt, sizeof(cstt),
    "AT+CSTT=\"%s\",\"%s\",\"%s\"",
    MAJISAFE_GPRS_APN, MAJISAFE_GPRS_USER, MAJISAFE_GPRS_PASS);
  atLine(cstt, 5000);
  atLine("AT+CIICR", 2000);
  delay(8000);
  String ip = atLine("AT+CIFSR", 5000);
  Serial.println("[IP] " + ip);
  return ip.indexOf('.') >= 0;
}

// ── Raw TCP HTTP/1.1 ──────────────────────────────────────────────────────────

bool Sim800::tcpSendHttp(const char *request, String &rawOut) {
  rawOut = "";
  atLine("AT+CIPSHUT", 8000);
  delay(1500);
  atLine("AT+CIPMUX=0", 3000);

  char start[128];
  snprintf(start, sizeof(start),
    "AT+CIPSTART=\"TCP\",\"%s\",%d",
    MAJISAFE_SERVER_HOST, MAJISAFE_SERVER_PORT);
  String cip = atLine(start, 20000);
  if (cip.indexOf("CONNECT") < 0 && cip.indexOf("OK") < 0) {
    delay(2000);
    while (Modem.available()) cip += static_cast<char>(Modem.read());
  }
  if (cip.indexOf("CONNECT") < 0) return false;

  size_t len = strlen(request);
  char cipsend[32];
  snprintf(cipsend, sizeof(cipsend), "AT+CIPSEND=%u", static_cast<unsigned>(len));
  flushIn();
  Modem.print(cipsend);
  Modem.print("\r\n");

  // Wait for '>' prompt
  uint32_t tPrompt = millis();
  bool gotGt = false;
  while (millis() - tPrompt < 10000) {
    while (Modem.available()) {
      if (static_cast<char>(Modem.read()) == '>') { gotGt = true; break; }
    }
    if (gotGt) break;
    delay(10);
  }
  if (!gotGt) { atLine("AT+CIPCLOSE", 3000); return false; }

  Modem.write(reinterpret_cast<const uint8_t *>(request), len);
  delay(50);

  // Read response (20 s window)
  uint32_t tRead = millis();
  while (millis() - tRead < 20000) {
    while (Modem.available()) rawOut += static_cast<char>(Modem.read());
    delay(15);
  }
  while (Modem.available()) rawOut += static_cast<char>(Modem.read());

  atLine("AT+CIPCLOSE", 5000);
  return rawOut.length() > 0;
}

// ── Station auth header builder ───────────────────────────────────────────────

static void buildStationHeaders(String &h) {
  h  = "X-Station-Id: ";     h += MAJISAFE_STATION_ID;     h += "\r\n";
  h += "X-Station-Secret: "; h += MAJISAFE_STATION_SECRET; h += "\r\n";
}

// ── Public HTTP methods ───────────────────────────────────────────────────────

bool Sim800::httpGetPath(const char *path, String &out) {
  if (!ensureGprs()) return false;
  String hdrs;
  buildStationHeaders(hdrs);
  String req  = "GET "; req += path;
  req += " HTTP/1.1\r\nHost: "; req += MAJISAFE_SERVER_HOST;
  req += ":"; req += MAJISAFE_SERVER_PORT; req += "\r\n";
  req += hdrs;
  req += "Connection: close\r\n\r\n";
  return tcpSendHttp(req.c_str(), out);
}

bool Sim800::httpPostJson(const char *path, const char *jsonBody, String &out) {
  if (!ensureGprs()) return false;
  String hdrs;
  buildStationHeaders(hdrs);
  size_t blen = strlen(jsonBody);
  String req  = "POST "; req += path;
  req += " HTTP/1.1\r\nHost: "; req += MAJISAFE_SERVER_HOST;
  req += ":"; req += MAJISAFE_SERVER_PORT; req += "\r\n";
  req += "Content-Type: application/json\r\n";
  req += hdrs;
  req += "Content-Length: "; req += static_cast<unsigned>(blen);
  req += "\r\nConnection: close\r\n\r\n";
  req += jsonBody;
  return tcpSendHttp(req.c_str(), out);
}
