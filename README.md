# MajiSafe

MajiSafe is a smart water dispensing and payment stack for Burundi, built around **REGIDESO Coins** (1 coin = 1 litre). Users top up in the **Regideso Wallet** Flutter app or via mobile-money SMS; the **Node.js API** holds balances and a tamper-evident ledger; **LilyGO T-Call** stations poll for commands over GPRS and run the physical dispense cycle.

The repository contains the backend API, the mobile client, and ESP32 firmware so you can run an end-to-end lab test on a LAN before field deployment.

## Architecture (ASCII)

```
┌─────────────────┐     HTTPS/JSON (JWT)      ┌──────────────────────┐
│ Regideso Wallet │ ◄──────────────────────► │  MajiSafe API        │
│ (Flutter)       │                           │  Express + SQLite    │
└─────────────────┘                           └──────────┬───────────┘
                                                         │
                        HTTP push (optional)              │  device + heartbeat
                        POST {dispense_url}             │  (station secret)
                                │                       │
                                ▼                       ▼
                        ┌───────────────────────────────────┐
                        │  ESP32 + SIM800L (T-Call)         │
                        │  Poll GET /dispense/device/pending │
                        │  Valve + flow meter → confirm/abort│
                        └───────────────────────────────────┘
```

**Push vs poll:** If `stations.dispense_url` is set, the server POSTs a dispense hint to the station after debiting coins. If that HTTP call fails after three retries, the server **refunds** the user and marks the transaction `failed`. Commands remain in `device_commands` for the firmware poll path in all cases.

## Repository layout

| Path | Role |
|------|------|
| `backend/` | Node 18+ API, SQLite (`data/majisafe.db`) |
| `majisafe_app/` | Flutter app (Regideso Wallet) |
| `firmware/` | PlatformIO project for LilyGO T-Call |

## Setup — backend

```bash
cd backend
cp .env.example .env
# Set JWT_SECRET (and optional JWT_REFRESH_SECRET, SMS_WEBHOOK_SECRET).
npm install
npm start
# default: http://127.0.0.1:3000
```

Health check: `curl -s http://127.0.0.1:3000/health`

Seed station **STN-001** uses `STATION_DEFAULT_SECRET` from `.env` unless you change it in the DB.

## Setup — Flutter app

```bash
cd majisafe_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://YOUR_HOST:3000
```

Android emulator: use `http://10.0.2.2:3000` for a backend on the host loopback.

## Setup — firmware

1. Install [PlatformIO](https://platformio.org/).
2. Edit `firmware/src/config/config.h`: **station id**, **secret** (must match `stations` row), **server host/port**, **GPRS APN**.
3. If the LCD is blank, try I²C address `0x3F` instead of `0x27` in `display.cpp`.
4. Build and flash:

```bash
cd firmware
pio run -t upload
pio device monitor
```

The modem stack uses **plain TCP HTTP/1.1** so custom headers (`X-Station-Id`, `X-Station-Secret`) work on SIM800; use an **HTTP** API URL or a tunnel—many SIM800 modules do not support TLS to arbitrary hosts.

## API reference (summary)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/auth/register` | — | Register |
| POST | `/api/auth/login` | — | Login |
| POST | `/api/auth/refresh` | — | Refresh tokens |
| GET | `/api/auth/me` | Bearer | Profile |
| GET | `/api/wallet/balance` | Bearer | Balance + recent tx |
| POST | `/api/wallet/topup` | Bearer | Create pending top-up |
| GET | `/api/wallet/history` | Bearer | Last 50 tx |
| POST | `/api/dispense/request` | Bearer | Debit + enqueue command |
| GET | `/api/dispense/status/:txId` | Bearer | Poll dispense state |
| GET | `/api/dispense/device/pending` | Station headers | Device pulls command |
| POST | `/api/dispense/confirm` | Station headers | Actual litres |
| POST | `/api/dispense/abort` | Station headers | Full refund path |
| POST | `/api/dispense/device/progress` | Station headers | Optional progress |
| GET | `/api/stations` | — | List stations |
| GET | `/api/stations/:id` | — | Station detail |
| POST | `/api/stations/heartbeat` | Station headers | Presence / telemetry |
| POST | `/api/sms/webhook` | Optional secret | Lumicash-style SMS |
| GET | `/api/sms/pending` | Admin | Unprocessed SMS |
| GET | `/api/admin/users` | Admin | Users |
| POST | `/api/admin/topup` | Admin | Manual coins |
| GET | `/api/admin/audit` | Admin | Ledger + chain check |
| GET | `/api/admin/stations` | Admin | Stations incl. secrets |

Station headers: `X-Station-Id` and `X-Station-Secret` (aliases `X-Majisafe-Station` / `X-Majisafe-Secret` also accepted).

## Hardware wiring (ESP32 → peripherals)

| ESP32 GPIO | Function | Notes |
|------------|----------|--------|
| 25 | Valve relay | **Not** GPIO26 — reserved for modem UART on T-Call |
| 35 | Flow sensor pulse | Input-only pin; add external pull resistor if needed |
| 21 | LCD SDA (I²C) | 16×2 I²C module |
| 22 | LCD SCL | |
| 19 / 18 / 5 | RGB LED | R / G / B |
| 27 / 26 | SIM800 UART | ESP RX ← modem TX on 27, ESP TX → modem RX on 26 (board-dependent) |

Always verify against your **exact** LilyGO T-Call revision.

## Integration smoke test

1. Start backend; register a user from the app or `curl`.
2. `POST /api/admin/topup` with `{ "user_id": 1, "coins": 20, "note": "test" }` (admin JWT or use seeded admin user).
3. Set `stations.dispense_url` if you want server push; otherwise rely on firmware polling only.
4. From the app: Dispense → STN-001 → small volume.
5. Confirm ledger: `GET /api/admin/audit` — `chain_valid` should be `true`.

---

**Security:** Change default station secrets, admin password, and JWT secrets before any production use. Prefer HTTPS termination in front of the API and a non-empty `SMS_WEBHOOK_SECRET` on public webhooks.
