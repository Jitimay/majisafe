/**
 * Station identity, connectivity, and pin map for LilyGO T-Call ESP32 + SIM800L.
 * Edit APN and server URL before flashing. Secrets must match backend `stations` row.
 */
#ifndef MAJISAFE_CONFIG_H
#define MAJISAFE_CONFIG_H

// --- Station identity (must match SQLite `stations.id` and `api_secret`) ---
#define MAJISAFE_STATION_ID "STN-001"
#define MAJISAFE_STATION_SECRET "station_shared_secret_change_me"

// --- Backend (HTTP; use plain HTTP unless your modem firmware supports HTTPS) ---
#define MAJISAFE_SERVER_HOST "192.168.1.100"
#define MAJISAFE_SERVER_PORT 3000

// --- GPRS APN (Burundi carriers — replace with your SIM) ---
#define MAJISAFE_GPRS_APN "internet"
#define MAJISAFE_GPRS_USER ""
#define MAJISAFE_GPRS_PASS ""

// --- Flow sensor: YF-S201 style, pulses per litre ---
#define MAJISAFE_PULSES_PER_LITRE 450.0f

// --- Hardware limits ---
#define MAJISAFE_MAX_LITRES_PER_TX 50.0f
#define MAJISAFE_VALVE_SAFETY_MS (120UL * 1000UL)
#define MAJISAFE_NO_FLOW_ABORT_MS (10UL * 1000UL)
#define MAJISAFE_POLL_PENDING_MS 5000UL
#define MAJISAFE_HEARTBEAT_MS (60UL * 1000UL)
#define MAJISAFE_FLOW_SAMPLE_MS 500UL

/**
 * Pin map: GPIO26 is UART RX to SIM800 on T-Call — do NOT use 26 for valve.
 * Valve relay on GPIO25 (change if your wiring differs).
 */
#define MAJISAFE_VALVE_PIN 25
#define MAJISAFE_FLOW_SENSOR_PIN 35

#define MAJISAFE_LCD_SDA 21
#define MAJISAFE_LCD_SCL 22

#define MAJISAFE_LED_R 19
#define MAJISAFE_LED_G 18
#define MAJISAFE_LED_B 5

#define MAJISAFE_MODEM_RX 27
#define MAJISAFE_MODEM_TX 26

#define MAJISAFE_FIRMWARE_VERSION "1.0.0"

#endif
