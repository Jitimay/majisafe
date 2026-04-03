/**
 * Runs one dispense cycle: valve, flow counting, confirm/abort over HTTP.
 */
#ifndef MAJISAFE_DISPENSE_SERVICE_H
#define MAJISAFE_DISPENSE_SERVICE_H

#include "../modules/sim800.h"

class DispenseService {
public:
  void begin(Sim800 *modem);
  bool start(const char *txId, float targetLitres);
  void tick();
  bool isBusy() const;

private:
  void finishAbort(const char *reason);
  void finishConfirm(float actual);
  void showLines(float cur, float target);

  Sim800 *m_modem;
  enum class Phase { Idle, Running };
  Phase m_phase;
  char m_txId[48];
  float m_target;
  uint32_t m_t0;
  uint32_t m_lastFlowMs;
  float m_lastL;
};

#endif
