/**
 * SIM800L: GPRS attach and raw TCP HTTP/1.1 client (custom headers for MajiSafe API).
 */
#ifndef MAJISAFE_SIM800_H
#define MAJISAFE_SIM800_H

#include <Arduino.h>

class Sim800 {
public:
  /** UART + basic AT probe. */
  bool begin();

  /** Bring up PDP context (APN from config). Call before HTTP. */
  bool ensureGprs();

  /**
   * GET path (leading slash), e.g. /api/dispense/device/pending.
   * Returns full TCP payload (headers + body) in out.
   */
  bool httpGetPath(const char *path, String &out);

  /**
   * POST JSON to path; Content-Type application/json.
   */
  bool httpPostJson(const char *path, const char *jsonBody, String &out);

private:
  bool tcpSendHttp(const char *request, String &rawOut);
  String atLine(const char *cmd, uint32_t timeoutMs);
  void flushIn();
};

#endif
