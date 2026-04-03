#include "sim800.h"
#include "../config/config.h"
#include <HardwareSerial.h>

static HardwareSerial Modem(1);

void Sim800::flushIn() {
  while (Modem.available()) {
    Modem.read();
  }
}

String Sim800::atLine(const char *cmd, uint32_t timeoutMs) {
  flushIn();
  Modem.print(cmd);
  Modem.print("\r\n");
  uint32_t t0 = millis();
  String acc;
  while (millis() - t0 < timeoutMs) {
    while (Modem.available()) {
      acc += static_cast<char>(Modem.read());
    }
    if (acc.indexOf("OK") >= 0 && acc.indexOf("\r\n") >= 0) {
      break;
    }
    if (acc.indexOf("ERROR") >= 0) {
      break;
    }
    delay(10);
  }
  return acc;
}

bool Sim800::begin() {
  Modem.begin(9600, SERIAL_8N1, MAJISAFE_MODEM_RX, MAJISAFE_MODEM_TX);
  delay(2500);
  String r = atLine("AT", 3000);
  if (r.indexOf("OK") < 0) {
    return false;
  }
  atLine("ATE0", 2000);
  atLine("AT+CFUN=1", 5000);
  delay(1500);
  return true;
}

bool Sim800::ensureGprs() {
  atLine("AT+CGATT=1", 5000);
  char cstt[96];
  snprintf(cstt, sizeof(cstt), "AT+CSTT=\"%s\",\"%s\",\"%s\"", MAJISAFE_GPRS_APN, MAJISAFE_GPRS_USER,
           MAJISAFE_GPRS_PASS);
  atLine(cstt, 5000);
  atLine("AT+CIICR", 2000);
  delay(8000);
  String ip = atLine("AT+CIFSR", 5000);
  if (ip.indexOf('.') < 0) {
    return false;
  }
  return true;
}

bool Sim800::tcpSendHttp(const char *request, String &rawOut) {
  rawOut = "";
  atLine("AT+CIPSHUT", 8000);
  delay(1500);
  atLine("AT+CIPMUX=0", 3000);
  char start[120];
  snprintf(start, sizeof(start), "AT+CIPSTART=\"TCP\",\"%s\",%d", MAJISAFE_SERVER_HOST, MAJISAFE_SERVER_PORT);
  String cip = atLine(start, 20000);
  if (cip.indexOf("CONNECT") < 0 && cip.indexOf("OK") < 0) {
    // Some firmware returns OK then CONNECT on next read
    delay(2000);
    while (Modem.available()) {
      cip += static_cast<char>(Modem.read());
    }
  }
  if (cip.indexOf("CONNECT") < 0) {
    return false;
  }

  size_t len = strlen(request);
  char cipsend[32];
  snprintf(cipsend, sizeof(cipsend), "AT+CIPSEND=%u", static_cast<unsigned>(len));
  flushIn();
  Modem.print(cipsend);
  Modem.print("\r\n");
  uint32_t tPrompt = millis();
  bool gotGt = false;
  while (millis() - tPrompt < 10000) {
    while (Modem.available()) {
      char c = static_cast<char>(Modem.read());
      if (c == '>') {
        gotGt = true;
        break;
      }
    }
    if (gotGt) {
      break;
    }
    delay(10);
  }
  if (!gotGt) {
    atLine("AT+CIPCLOSE", 3000);
    return false;
  }

  Modem.write(reinterpret_cast<const uint8_t *>(request), len);
  delay(50);

  uint32_t tRead = millis();
  while (millis() - tRead < 20000) {
    while (Modem.available()) {
      rawOut += static_cast<char>(Modem.read());
    }
    delay(15);
  }
  while (Modem.available()) {
    rawOut += static_cast<char>(Modem.read());
  }

  atLine("AT+CIPCLOSE", 5000);
  return rawOut.length() > 0;
}

static void buildStationHeaders(String &h) {
  h = "X-Station-Id: ";
  h += MAJISAFE_STATION_ID;
  h += "\r\nX-Station-Secret: ";
  h += MAJISAFE_STATION_SECRET;
  h += "\r\n";
}

bool Sim800::httpGetPath(const char *path, String &out) {
  if (!ensureGprs()) {
    return false;
  }
  String hdrs;
  buildStationHeaders(hdrs);
  String req = "GET ";
  req += path;
  req += " HTTP/1.1\r\nHost: ";
  req += MAJISAFE_SERVER_HOST;
  req += ":";
  req += MAJISAFE_SERVER_PORT;
  req += "\r\n";
  req += hdrs;
  req += "Connection: close\r\n\r\n";
  return tcpSendHttp(req.c_str(), out);
}

bool Sim800::httpPostJson(const char *path, const char *jsonBody, String &out) {
  if (!ensureGprs()) {
    return false;
  }
  String hdrs;
  buildStationHeaders(hdrs);
  size_t blen = strlen(jsonBody);
  String req = "POST ";
  req += path;
  req += " HTTP/1.1\r\nHost: ";
  req += MAJISAFE_SERVER_HOST;
  req += ":";
  req += MAJISAFE_SERVER_PORT;
  req += "\r\nContent-Type: application/json\r\n";
  req += hdrs;
  req += "Content-Length: ";
  req += static_cast<unsigned>(blen);
  req += "\r\nConnection: close\r\n\r\n";
  req += jsonBody;
  return tcpSendHttp(req.c_str(), out);
}
