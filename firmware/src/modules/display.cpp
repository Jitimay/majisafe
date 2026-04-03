#include "display.h"
#include "../config/config.h"
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

static LiquidCrystal_I2C lcd(0x27, 16, 2);

void Display::begin() {
  Wire.begin(MAJISAFE_LCD_SDA, MAJISAFE_LCD_SCL);
  lcd.init();
  lcd.backlight();
  lcd.clear();
}

void Display::show(const char *line1, const char *line2) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1);
  lcd.setCursor(0, 1);
  lcd.print(line2);
}
