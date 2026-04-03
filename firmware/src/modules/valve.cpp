#include "valve.h"
#include "../config/config.h"

static bool s_open = false;

void Valve::begin() {
  pinMode(MAJISAFE_VALVE_PIN, OUTPUT);
  digitalWrite(MAJISAFE_VALVE_PIN, LOW);
  s_open = false;
}

void Valve::openValve() {
  digitalWrite(MAJISAFE_VALVE_PIN, HIGH);
  s_open = true;
}

void Valve::closeValve() {
  digitalWrite(MAJISAFE_VALVE_PIN, LOW);
  s_open = false;
}

bool Valve::isOpen() {
  return s_open;
}
