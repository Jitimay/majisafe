/**
 * RGB status LED (ready / working / error).
 */
#ifndef MAJISAFE_LED_INDICATOR_H
#define MAJISAFE_LED_INDICATOR_H

namespace LedIndicator {
enum class Mode { Off, Ready, Connecting, Dispensing, Error };

void begin();
void set(Mode m);
void tickBlink();
} // namespace LedIndicator

#endif
