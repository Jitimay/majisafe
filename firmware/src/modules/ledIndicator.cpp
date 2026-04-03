#include "ledIndicator.h"
#include "../config/config.h"
#include <Arduino.h>

static LedIndicator::Mode s_mode = LedIndicator::Mode::Off;
static uint32_t s_blink = 0;
static bool s_on = false;

static void writeRgb(bool r, bool g, bool b) {
  digitalWrite(MAJISAFE_LED_R, r ? HIGH : LOW);
  digitalWrite(MAJISAFE_LED_G, g ? HIGH : LOW);
  digitalWrite(MAJISAFE_LED_B, b ? HIGH : LOW);
}

void LedIndicator::begin() {
  pinMode(MAJISAFE_LED_R, OUTPUT);
  pinMode(MAJISAFE_LED_G, OUTPUT);
  pinMode(MAJISAFE_LED_B, OUTPUT);
  set(Mode::Ready);
}

void LedIndicator::set(Mode m) {
  s_mode = m;
  s_blink = millis();
  s_on = true;
  switch (m) {
  case Mode::Off:
    writeRgb(false, false, false);
    break;
  case Mode::Ready:
    writeRgb(false, true, false);
    break;
  case Mode::Connecting:
    writeRgb(false, false, true);
    break;
  case Mode::Dispensing:
    writeRgb(false, false, true);
    break;
  case Mode::Error:
    writeRgb(true, false, false);
    break;
  }
}

void LedIndicator::tickBlink() {
  if (s_mode != Mode::Connecting) {
    return;
  }
  uint32_t now = millis();
  if (now - s_blink < 400) {
    return;
  }
  s_blink = now;
  s_on = !s_on;
  writeRgb(false, false, s_on);
}
