/**
 * 16x2 I2C LCD status lines.
 */
#ifndef MAJISAFE_DISPLAY_H
#define MAJISAFE_DISPLAY_H

namespace Display {
void begin();
void show(const char *line1, const char *line2);
} // namespace Display

#endif
