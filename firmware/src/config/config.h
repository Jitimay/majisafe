/**
 * Station identity, connectivity, and pin map for LilyGO T-Call ESP32 + SIM800L.
 * Edit APN and server URL before flashing. Secrets must match backend `stations` row.
 */
#ifndef MAJISAFE_CONFIG_H
#define MAJISAFE_CONFIG_H

// --- Station identity (must match SQLite `stations.id` and `api_secret`) ---
#define MAJISAFE_STATION_ID     "STN-001"
#define MAJISAFE_STATION_SECRET "station_shared_secret_change_me"

// --- Backend on Andasy (plain HTTP — SIM800L does not support TLS) ---
#define MAJISAFE_SERVER_HOST "majisafe-backend.andasy.dev"
#define MAJISAFE_SERVER_PORT 80

// --- GPRS APN (Burundi carriers — replace with your SIM) ---
#define MAJISAFE_GPRS_APN  "internet"
#define MAJISAFE_GPRS_USER ""
#define MAJISAFE_GPRS_PASS ""

// --- Flow sensor: YF-S201 style, pulses per litre ---
#define MAJISAFE_PULSES_PER_LITRE 450.0f

// --- Hardware limits ---
#define MAJISAFE_MAX_LITRES_PER_TX    50.0f
#define MAJISAFE_VALVE_SAFETY_MS      (120UL * 1000UL)
#define MAJISAFE_NO_FLOW_ABORT_MS     (10UL  * 1000UL)
#define MAJISAFE_POLL_PENDING_MS      5000UL
#define MAJISAFE_HEARTBEAT_MS         (60UL  * 1000UL)
#define MAJISAFE_FLOW_SAMPLE_MS       500UL

// ── TTGO T-Call v1.3 / v1.4 modem power pins ─────────────────────────────────
// These must be driven before the UART is opened.
#define MAJISAFE_MODEM_PWKEY    4
#define MAJISAFE_MODEM_RST      5
#define MAJISAFE_MODEM_POWER_ON 23

// ── UART to SIM800L ───────────────────────────────────────────────────────────
// On T-Call: ESP TX→26 (modem RX), ESP RX←27 (modem TX).
// GPIO 26 is also the modem UART — do NOT use it for anything else.
#define MAJISAFE_MODEM_TX 26   // ESP → modem
#define MAJISAFE_MODEM_RX 27   // modem → ESP

// ── Water valve relay ─────────────────────────────────────────────────────────
#define MAJISAFE_VALVE_PIN       25   // NOT GPIO26 (reserved for modem UART)

// ── Flow sensor ───────────────────────────────────────────────────────────────
#define MAJISAFE_FLOW_SENSOR_PIN 35   // input-only; add external pull-up if needed

// ── I²C LCD (16×2) ───────────────────────────────────────────────────────────
#define MAJISAFE_LCD_SDA 21
#define MAJISAFE_LCD_SCL 22

// ── RGB status LED ────────────────────────────────────────────────────────────
#define MAJISAFE_LED_R 19
#define MAJISAFE_LED_G 18
#define MAJISAFE_LED_B  5

// ── Pump relay pins (Arduino 8-relay module) ──────────────────────────────────
#define MAJISAFE_PUMP_1_PIN 33   // Relay CH2 → Pump 1
#define MAJISAFE_PUMP_2_PIN 32   // Relay CH3 → Pump 2

// ── Tank simulation ───────────────────────────────────────────────────────────
#define MAJISAFE_TANK_CAPACITY_LITRES     5000.0f
#define MAJISAFE_PUMP_FILL_RATE_PCT_PER_S 0.005f   // 0→100 % in ~200 s
#define MAJISAFE_PUMP_POLL_MS             10000UL
#define MAJISAFE_NVS_PERSIST_INTERVAL_MS  60000UL

// ── NVS keys ──────────────────────────────────────────────────────────────────
#define MAJISAFE_NVS_NAMESPACE "majisafe"
#define MAJISAFE_NVS_TANK_KEY  "tank_pct"

#define MAJISAFE_FIRMWARE_VERSION "1.1.0"

#endif
