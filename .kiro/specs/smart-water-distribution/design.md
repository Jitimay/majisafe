# Design Document — Smart Water Distribution Platform

## Overview

The Smart Water Distribution Platform adds pump control, simulated tank-level tracking, a rule-based AI recommendation engine, analytics, and a React web dashboard to the existing MajiSafe system.

The feature spans three components:

- **Backend** (`backend/`) — new SQLite tables, new Express routes under `/api/pumps/*` and `/api/analytics/*`, and a pure-JS recommendation engine.
- **Dashboard** (`dashboard/`) — a new React + Vite + Tailwind + Recharts single-page application deployed as a second Andasy app.
- **Firmware** (`firmware/`) — additions to the existing PlatformIO C++ application: a pump polling loop, GPIO relay control, NVS-persisted tank simulation, and an extended heartbeat payload.

Tank level is **simulated** — there is no physical sensor. The firmware estimates level by decrementing on confirmed dispenses and incrementing while a pump relay is energised. The backend records every heartbeat's `tank_level` value into a time-series table for analytics.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Dashboard (React/Vite)  ← VITE_API_BASE_URL →  Backend (Express)  │
│  dashboard.andasy.dev                           majisafe-backend.   │
│                                                 andasy.dev          │
│  React Query (30 s poll)                                            │
│  JWT in localStorage                            SQLite (WAL mode)   │
│                                                                     │
│  /login → POST /api/auth/login                                      │
│  /api/pumps/*   (admin JWT)                                         │
│  /api/analytics/* (admin JWT)                                       │
│  /api/stations  (public)                                            │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ GPRS / HTTP
                    ┌──────────▼──────────┐
                    │  TTGO T-Call ESP32  │
                    │  (firmware)         │
                    │                     │
                    │  POST /heartbeat    │  ← every 60 s
                    │  GET  /pumps/pending│  ← every 10 s
                    │  POST /pumps/ack    │  ← after GPIO action
                    │                     │
                    │  GPIO 33 → Relay 1  │  → Pump 1
                    │  GPIO 32 → Relay 2  │  → Pump 2
                    └─────────────────────┘
```

### Key Design Decisions

1. **SQLite WAL mode** is already in use; new tables follow the same migration pattern in `runMigrations()`.
2. **Station auth** (`X-Station-Id` / `X-Station-Secret` headers) is reused for the new pump polling and ack endpoints — no new auth mechanism needed.
3. **Admin JWT** (existing `authMiddleware` + `adminOnly` middleware) gates all dashboard-facing pump and analytics endpoints.
4. **Pump runtime** is accumulated server-side from heartbeat `pump_N_runtime_seconds` fields rather than computed in the DB, keeping the firmware as the authoritative clock.
5. **Tank capacity** is a backend constant (`TANK_CAPACITY_LITRES = 5000`) used only in the time-to-empty calculation; the firmware uses its own `PUMP_FILL_RATE_PERCENT_PER_SECOND` constant.
6. **React Query** handles all data fetching, caching, and the 30-second auto-refresh; no additional state management library is needed.

---

## Components and Interfaces

### Backend — New Files

```
backend/src/
  controllers/
    pumpsController.js       ← pump command CRUD + ack
    analyticsController.js   ← all analytics queries
  routes/
    pumps.js                 ← /api/pumps/:stationId/*
    analytics.js             ← /api/analytics/:stationId/*
  services/
    recommendationEngine.js  ← pure-JS rule-based AI
```

`server.js` gains two new `app.use()` lines:

```js
import pumpsRoutes    from './routes/pumps.js';
import analyticsRoutes from './routes/analytics.js';
// ...
app.use('/api/pumps',     pumpsRoutes);
app.use('/api/analytics', analyticsRoutes);
```

### Backend — Modified Files

| File | Change |
|---|---|
| `backend/src/models/db.js` | Add `pump_commands`, `tank_level_history`, pump columns on `stations` to `runMigrations()` |
| `backend/src/controllers/stationsController.js` | `heartbeat()` extended to accept and persist new pump fields, insert `tank_level_history` row |
| `backend/src/routes/stations.js` | Heartbeat validator extended for new fields |

### Dashboard — New Project

```
dashboard/
  andasy.hcl
  index.html
  package.json
  vite.config.js
  tailwind.config.js
  postcss.config.js
  src/
    main.jsx
    App.jsx
    api/
      client.js            ← axios instance with JWT interceptor
      pumps.js
      analytics.js
      stations.js
      auth.js
    components/
      TankGauge.jsx
      PumpCard.jsx
      RecommendationPanel.jsx
      DailyChart.jsx
      HeatmapGrid.jsx
      StationList.jsx
      StationDetail.jsx
      LoadingSpinner.jsx
      ToastNotification.jsx
    pages/
      LoginPage.jsx
      DashboardPage.jsx
      StationDetailPage.jsx
    hooks/
      useStations.js
      usePumpStatus.js
      useRecommendation.js
      useAnalytics.js
    context/
      AuthContext.jsx
    router.jsx
```

### Firmware — New / Modified Files

| File | Change |
|---|---|
| `firmware/src/config/config.h` | Add `PUMP_1_PIN`, `PUMP_2_PIN`, `TANK_CAPACITY_LITRES`, `PUMP_FILL_RATE_PERCENT_PER_SECOND`, `PUMP_POLL_MS`, NVS key constants |
| `firmware/src/modules/pump.h/.cpp` | New module: GPIO init, activate/deactivate, runtime accumulation |
| `firmware/src/services/tankSimulator.h/.cpp` | New service: NVS-persisted level, fill/drain logic |
| `firmware/src/services/pumpPoller.h/.cpp` | New service: polls `/api/pumps/:stationId/pending`, executes command, sends ack |
| `firmware/src/services/heartbeat.cpp` | Extended payload with pump and tank fields |
| `firmware/src/main.cpp` | `setup()` initialises pump module and tank simulator; `loop()` calls `PumpPoller::tick()` and `TankSimulator::tick()` |

---

## Data Models

### New DB Tables (added in `runMigrations()`)

#### `pump_commands`

```sql
CREATE TABLE IF NOT EXISTS pump_commands (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  station_id   TEXT    NOT NULL REFERENCES stations(id),
  pump_number  INTEGER NOT NULL CHECK (pump_number IN (1, 2)),
  action       TEXT    NOT NULL CHECK (action IN ('activate', 'deactivate')),
  status       TEXT    NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending', 'sent', 'acknowledged')),
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  acknowledged_at DATETIME
);

CREATE INDEX IF NOT EXISTS idx_pump_commands_station_status
  ON pump_commands(station_id, status);
```

#### `tank_level_history`

```sql
CREATE TABLE IF NOT EXISTS tank_level_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  station_id  TEXT    NOT NULL REFERENCES stations(id),
  tank_level  REAL    NOT NULL CHECK (tank_level BETWEEN 0 AND 100),
  recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tank_level_history_station_time
  ON tank_level_history(station_id, recorded_at);
```

#### `pump_status` — stored as columns on `stations` (ALTER TABLE migration)

Rather than a separate table (which would require a join on every heartbeat), pump state is stored directly on the `stations` row. The migration adds these columns if absent:

```sql
ALTER TABLE stations ADD COLUMN pump_1_active       INTEGER DEFAULT 0;
ALTER TABLE stations ADD COLUMN pump_2_active       INTEGER DEFAULT 0;
ALTER TABLE stations ADD COLUMN pump_1_runtime_hours REAL   DEFAULT 0;
ALTER TABLE stations ADD COLUMN pump_2_runtime_hours REAL   DEFAULT 0;
```

The migration guard pattern already used in `db.js` (`PRAGMA table_info` check) is applied here.

### Firmware Data Structures

```cpp
// tankSimulator.h
namespace TankSimulator {
  static constexpr char NVS_NAMESPACE[] = "majisafe";
  static constexpr char NVS_KEY[]       = "tank_pct";

  void   begin();                    // load from NVS or default 100.0
  void   tick();                     // called every loop(); handles fill rate
  void   onDispenseComplete(float actual_litres);
  float  getLevel();                 // returns [0.0, 100.0]
  void   persist();                  // write to NVS
}

// pump.h
namespace Pump {
  void  begin();
  void  activate(uint8_t pumpNumber);    // sets GPIO HIGH
  void  deactivate(uint8_t pumpNumber);  // sets GPIO LOW
  bool  isActive(uint8_t pumpNumber);
  float getRuntimeSeconds(uint8_t pumpNumber);
  void  tickRuntime();               // called every loop(); accumulates seconds
}

// pumpPoller.h
namespace PumpPoller {
  void begin(Sim800 *modem);
  void tick();                       // polls every PUMP_POLL_MS when not dispensing
}
```

### Dashboard API Response Types (TypeScript-style for clarity)

```ts
interface Station {
  id: string; name: string; location: string;
  status: 'online' | 'offline' | 'dispensing' | 'error';
  tank_level: number;          // 0–100
  last_seen: string;           // ISO-8601
  pump_1_active: boolean;
  pump_2_active: boolean;
  pump_1_runtime_hours: number;
  pump_2_runtime_hours: number;
}

interface PumpCommand {
  id: number; station_id: string;
  pump_number: 1 | 2;
  action: 'activate' | 'deactivate';
  status: 'pending' | 'sent' | 'acknowledged';
  created_at: string;
}

interface Recommendation {
  action: 'activate_pump_1' | 'activate_pump_2' | 'deactivate_pump' | 'no_action';
  pump_number: 1 | 2 | null;
  reason: string;              // max 120 chars
  urgency: 'high' | 'medium' | 'low';
}

interface TankHistoryRow { id: number; station_id: string; tank_level: number; recorded_at: string; }
interface DailyUsageRow  { date: string; total_litres: number; }
interface HeatmapMatrix  { matrix: number[][]; }  // [7][24]
interface DepletionRate  { litres_per_hour: number; tank_level_percent: number; }
interface TimeToEmpty    { estimated_minutes: number | null; }
```

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Pump command insertion round-trip

*For any* valid `(stationId, pump_number ∈ {1,2}, action ∈ {activate, deactivate})` triple submitted by an admin user, the `POST /api/pumps/:stationId/command` endpoint SHALL return a response containing a numeric `id` and an ISO-8601 `created_at`, and a corresponding row with `status = 'pending'` SHALL exist in the `pump_commands` table.

**Validates: Requirements 1.1, 1.2**

---

### Property 2: Non-admin requests are always rejected

*For any* request to `POST /api/pumps/:stationId/command` made by a user whose `role` is not `admin`, the response SHALL always be HTTP 403 regardless of the payload content.

**Validates: Requirements 1.3**

---

### Property 3: Pump poll returns oldest pending command and advances its status

*For any* sequence of N ≥ 1 pump commands inserted for a station, a call to `GET /api/pumps/:stationId/pending` SHALL return the command with the lowest `id` among those with `status = 'pending'`, and that command's status SHALL be updated to `sent` atomically.

**Validates: Requirements 1.7**

---

### Property 4: Pump ack updates command status and station pump fields

*For any* `command_id` with `status = 'sent'` and any `(pump_status_1, pump_status_2)` boolean pair, a call to `POST /api/pumps/:stationId/ack` SHALL set the command's `status` to `acknowledged` and update `stations.pump_1_active` and `stations.pump_2_active` to the provided values.

**Validates: Requirements 1.8**

---

### Property 5: Heartbeat inserts tank_level_history row

*For any* `tank_level` value in [0.0, 100.0] sent in a firmware heartbeat, the backend SHALL insert exactly one row into `tank_level_history` for that station with the matching `tank_level` value and a `recorded_at` timestamp within 1 second of the request time.

**Validates: Requirements 2.2**

---

### Property 6: Tank history query result is ordered ascending

*For any* set of `tank_level_history` rows for a station, the response from `GET /api/analytics/:stationId/tank-history` SHALL return all matching rows sorted by `recorded_at` in ascending order.

**Validates: Requirements 2.3**

---

### Property 7: Tank simulation arithmetic invariant

*For any* starting `tank_level_percent` in [0.0, 100.0], any `actual_litres` dispensed, and any number of seconds N with a pump active, the resulting `tank_level_percent` SHALL equal `clamp(start - (actual_litres / TANK_CAPACITY_LITRES) * 100 + N * PUMP_FILL_RATE_PERCENT_PER_SECOND, 0.0, 100.0)`, and the value SHALL never leave the range [0.0, 100.0].

**Validates: Requirements 3.2, 3.3, 3.4**

---

### Property 8: Tank level NVS persistence round-trip

*For any* `tank_level_percent` value written to NVS, reading it back after a simulated reboot SHALL return the same value (within float32 precision).

**Validates: Requirements 3.6**

---

### Property 9: Heartbeat payload completeness

*For any* combination of `(pump_1_active, pump_2_active)` boolean states and any `(pump_1_runtime_seconds, pump_2_runtime_seconds)` non-negative values, the serialised heartbeat JSON SHALL contain all six fields: `tank_level`, `pump_1_active`, `pump_2_active`, `pump_1_runtime_seconds`, `pump_2_runtime_seconds`, and `status`.

**Validates: Requirements 4.4, 4.5**

---

### Property 10: Recommendation response shape and reason length

*For any* station state (any `tank_level`, any pump active/inactive combination, any runtime values), the `GET /api/analytics/:stationId/recommendation` response SHALL contain `action`, `pump_number`, `reason`, and `urgency` fields, and `reason.length` SHALL be ≤ 120 characters.

**Validates: Requirements 5.1, 5.7**

---

### Property 11: Recommendation logic — low tank, no pump active

*For any* station where `tank_level < 30` and both pumps are inactive, the recommendation `action` SHALL be either `activate_pump_1` or `activate_pump_2`, and the recommended pump SHALL be the one with the lower `runtime_hours` (Pump 1 when equal).

**Validates: Requirements 5.2, 5.6**

---

### Property 12: Recommendation logic — low tank, pump already active

*For any* station where `tank_level < 30` and at least one pump is active, the recommendation `action` SHALL be `no_action` and `urgency` SHALL be `low`.

**Validates: Requirements 5.3**

---

### Property 13: Recommendation logic — high tank, pump active

*For any* station where `tank_level > 80` and at least one pump is active, the recommendation `action` SHALL be `deactivate_pump`.

**Validates: Requirements 5.4**

---

### Property 14: Recommendation logic — mid-range tank

*For any* station where `tank_level` is in [30.0, 80.0], the recommendation `action` SHALL be `no_action` and `urgency` SHALL be `low`.

**Validates: Requirements 5.5**

---

### Property 15: Daily usage array shape

*For any* `days` value in [1, 90] and any set of confirmed transactions, the `GET /api/analytics/:stationId/daily-usage` response SHALL return an array of exactly `days` objects each containing a `date` string and a non-negative `total_litres` number.

**Validates: Requirements 6.1**

---

### Property 16: Hourly heatmap is always 7 × 24

*For any* set of confirmed transactions (including an empty set), the `GET /api/analytics/:stationId/hourly-heatmap` response SHALL return a matrix with exactly 7 rows and exactly 24 columns, with all values ≥ 0.

**Validates: Requirements 6.2**

---

### Property 17: Time-to-empty formula

*For any* `tank_level_percent` in (0, 100] and any `litres_per_hour > 0`, the `estimated_minutes` returned by `GET /api/analytics/:stationId/time-to-empty` SHALL equal `(tank_level_percent / 100 * TANK_CAPACITY_LITRES) / litres_per_hour * 60`. When `litres_per_hour = 0`, `estimated_minutes` SHALL be `null`.

**Validates: Requirements 6.4**

---

### Property 18: Analytics endpoints reject non-admin callers

*For any* analytics endpoint and any request carrying no JWT, an expired JWT, or a JWT belonging to a non-admin user, the response SHALL be HTTP 401 or HTTP 403.

**Validates: Requirements 6.6**

---

## Error Handling

### Backend

All error responses follow the existing `apiError(code, message)` shape:

```json
{ "success": false, "error": { "code": "ERROR_CODE", "message": "Human-readable message" } }
```

| Scenario | HTTP | Code |
|---|---|---|
| Non-admin calls pump/analytics endpoint | 403 | `FORBIDDEN` |
| `pump_number` not 1 or 2 | 400 | `INVALID_PUMP` |
| `action` not activate/deactivate | 400 | `INVALID_ACTION` |
| `station_id` not in `stations` | 404 | `STATION_NOT_FOUND` |
| `from`/`to` not valid ISO-8601 | 400 | `INVALID_DATE` |
| `days` < 1 or > 90 | 400 | `INVALID_RANGE` |
| `command_id` not found or wrong station | 404 | `COMMAND_NOT_FOUND` |
| DB or unexpected error | 500 | `INTERNAL_ERROR` |

The recommendation engine never throws — it returns a `no_action / low` recommendation when station data is missing or malformed, logging a warning.

### Dashboard

- **Auth errors** (401/403): `AuthContext` catches these globally via an Axios response interceptor, clears the JWT, and redirects to `/login`.
- **Network errors on auto-refresh**: React Query's `onError` callback triggers a toast notification "Connection lost — retrying…". The query continues retrying on its 30-second interval.
- **Pump toggle failure**: The `PumpCard` component catches the mutation error and displays an inline error message, re-enabling the toggle button.
- **Stale data indicator**: `StationList` computes `Date.now() - new Date(last_seen)` and shows a yellow "Stale" badge when > 5 minutes.

### Firmware

- **GPRS unavailable on ack**: `PumpPoller` stores the pending ack payload in a static buffer and retries on the next successful `tick()` call.
- **NVS read failure on boot**: `TankSimulator::begin()` defaults to 100.0 % and logs a warning via `Serial`.
- **GPIO safety**: `Pump::begin()` sets both relay pins LOW before any polling starts, ensuring pumps are off on boot.

---

## Testing Strategy

### Unit Tests (Backend — Jest / Node test runner)

Focus on specific examples and edge cases:

- `pumpsController`: valid command insertion, 403 on non-admin, 400 on invalid pump/action, 404 on missing station, ack state transitions.
- `analyticsController`: daily-usage with known transaction set, heatmap dimensions, time-to-empty formula with known values, 400 on invalid `days`.
- `stationsController.heartbeat`: tank_level_history row insertion, pump field update.
- `recommendationEngine`: all four rule branches with concrete inputs, tie-breaking (equal runtimes → Pump 1), reason length ≤ 120.

### Property-Based Tests (Backend — fast-check)

The project uses [fast-check](https://fast-check.io/) (pure-JS, no additional runtime). Each property test runs a minimum of 100 iterations.

Tag format: `// Feature: smart-water-distribution, Property N: <property_text>`

Properties to implement as fast-check tests:

| Property | fast-check arbitraries |
|---|---|
| P1: Pump command round-trip | `fc.integer({min:1,max:2})`, `fc.constantFrom('activate','deactivate')` |
| P2: Non-admin always 403 | `fc.record({role: fc.string().filter(r => r !== 'admin')})` |
| P3: Poll returns oldest pending | `fc.array(fc.record({...}), {minLength:1})` |
| P4: Ack updates status and pump fields | `fc.boolean()`, `fc.boolean()` |
| P5: Heartbeat inserts history row | `fc.float({min:0,max:100})` |
| P6: History ordered ascending | `fc.array(fc.date())` |
| P7: Tank simulation arithmetic | `fc.float({min:0,max:100})`, `fc.float({min:0,max:50})`, `fc.integer({min:0,max:3600})` |
| P10: Recommendation shape + reason ≤ 120 | `fc.record({tank_level: fc.float({min:0,max:100}), ...})` |
| P11–P14: Recommendation logic branches | `fc.float` in specific ranges |
| P15: Daily usage array length = days | `fc.integer({min:1,max:90})` |
| P16: Heatmap always 7×24 | `fc.array(fc.record({...}))` |
| P17: Time-to-empty formula | `fc.float({min:0.01,max:100})`, `fc.float({min:0.01,max:1000})` |
| P18: Analytics rejects non-admin | `fc.constantFrom(null, 'user', 'operator')` |

### Firmware Tests (Unity / PlatformIO native)

- `TankSimulator`: arithmetic invariant (P7), NVS round-trip (P8), clamp boundary.
- `Pump`: GPIO state after activate/deactivate, runtime accumulation.
- `PumpPoller`: JSON parsing of pending command response, ack payload serialisation.
- `Heartbeat`: payload contains all required fields (P9).

### Dashboard Tests (Vitest + React Testing Library)

- `LoginPage`: renders form, calls `/api/auth/login`, stores JWT, rejects non-admin role.
- `TankGauge`: renders correct colour for level < 20, 20–49, ≥ 50; shows "Offline" overlay.
- `PumpCard`: shows ON/OFF badge, disables toggle on pending, shows error on API failure.
- `RecommendationPanel`: renders urgency colours, hides Apply on `no_action`.
- `DailyChart`: renders "No data" placeholder when array is empty.
- `HeatmapGrid`: renders 7 × 24 cells.
- `StationList`: shows "Stale" badge when `last_seen` > 5 min.

### Integration / Smoke Tests

- Backend starts and `/health` returns 200.
- All new routes are registered (smoke: `GET /api/pumps/STN-001/status` returns 401 without auth).
- Dashboard builds with `npm run build` and `dist/` is non-empty.

---

## API Contracts

All new endpoints follow the existing conventions: JSON bodies, `Authorization: Bearer <jwt>` for admin routes, `X-Station-Id` + `X-Station-Secret` headers for firmware routes.

---

### Pump Endpoints (`/api/pumps`)

#### `POST /api/pumps/:stationId/command`

Auth: Admin JWT

**Request**
```json
{
  "pump_number": 1,
  "action": "activate"
}
```

**Response 200**
```json
{
  "success": true,
  "id": 42,
  "station_id": "STN-001",
  "pump_number": 1,
  "action": "activate",
  "status": "pending",
  "created_at": "2025-01-15T10:30:00.000Z"
}
```

**Error responses**

| Condition | HTTP | body.error.code |
|---|---|---|
| Non-admin user | 403 | `FORBIDDEN` |
| pump_number not 1 or 2 | 400 | `INVALID_PUMP` |
| action not activate/deactivate | 400 | `INVALID_ACTION` |
| station_id not found | 404 | `STATION_NOT_FOUND` |

---

#### `GET /api/pumps/:stationId/pending`

Auth: Station (`X-Station-Id` / `X-Station-Secret`)

**Response 200 — command available**
```json
{
  "success": true,
  "command": {
    "id": 42,
    "pump_number": 1,
    "action": "activate"
  }
}
```

**Response 200 — no pending command**
```json
{
  "success": true,
  "command": null
}
```

---

#### `POST /api/pumps/:stationId/ack`

Auth: Station

**Request**
```json
{
  "command_id": 42,
  "pump_status_1": true,
  "pump_status_2": false
}
```

**Response 200**
```json
{
  "success": true,
  "command_id": 42,
  "acknowledged_at": "2025-01-15T10:30:05.000Z"
}
```

**Error responses**

| Condition | HTTP | code |
|---|---|---|
| command_id not found or wrong station | 404 | `COMMAND_NOT_FOUND` |

---

#### `GET /api/pumps/:stationId/status`

Auth: Admin JWT

**Response 200**
```json
{
  "success": true,
  "station_id": "STN-001",
  "pump_1_active": true,
  "pump_2_active": false,
  "pump_1_runtime_hours": 12.5,
  "pump_2_runtime_hours": 8.2
}
```

---

### Analytics Endpoints (`/api/analytics`)

All analytics endpoints require Admin JWT.

#### `GET /api/analytics/:stationId/tank-history`

Query params: `from` (ISO-8601, optional), `to` (ISO-8601, optional)

**Response 200**
```json
{
  "success": true,
  "station_id": "STN-001",
  "rows": [
    { "id": 1, "tank_level": 95.2, "recorded_at": "2025-01-15T08:00:00.000Z" },
    { "id": 2, "tank_level": 91.7, "recorded_at": "2025-01-15T09:00:00.000Z" }
  ]
}
```

**Error responses**

| Condition | HTTP | code |
|---|---|---|
| from or to not valid ISO-8601 | 400 | `INVALID_DATE` |
| station not found | 404 | `STATION_NOT_FOUND` |

---

#### `GET /api/analytics/:stationId/recommendation`

**Response 200**
```json
{
  "success": true,
  "station_id": "STN-001",
  "recommendation": {
    "action": "activate_pump_1",
    "pump_number": 1,
    "reason": "Tank at 22% — below 30% threshold. Pump 1 has fewer runtime hours (8.2h vs 12.5h).",
    "urgency": "high"
  }
}
```

Possible `action` values: `activate_pump_1`, `activate_pump_2`, `deactivate_pump`, `no_action`
Possible `urgency` values: `high`, `medium`, `low`

---

#### `GET /api/analytics/:stationId/daily-usage`

Query params: `days` (integer 1–90, default 7)

**Response 200**
```json
{
  "success": true,
  "station_id": "STN-001",
  "days": 7,
  "data": [
    { "date": "2025-01-09", "total_litres": 320.5 },
    { "date": "2025-01-10", "total_litres": 415.0 },
    { "date": "2025-01-11", "total_litres": 0 },
    { "date": "2025-01-12", "total_litres": 280.3 },
    { "date": "2025-01-13", "total_litres": 510.8 },
    { "date": "2025-01-14", "total_litres": 390.1 },
    { "date": "2025-01-15", "total_litres": 125.0 }
  ]
}
```

**Error responses**

| Condition | HTTP | code |
|---|---|---|
| days < 1 or > 90 | 400 | `INVALID_RANGE` |

---

#### `GET /api/analytics/:stationId/hourly-heatmap`

**Response 200**
```json
{
  "success": true,
  "station_id": "STN-001",
  "days_of_week": ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"],
  "hours": [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23],
  "matrix": [
    [0,0,0,0,0,2.1,5.3,12.4,18.2,15.0,14.1,16.3,20.5,18.7,17.2,15.8,14.0,12.1,10.3,8.5,6.2,4.1,2.0,0.5],
    [0,0,0,0,0,1.8,4.9,11.2,17.5,14.3,13.8,15.9,19.8,17.4,16.5,14.9,13.2,11.5,9.8,7.9,5.8,3.7,1.8,0.3]
  ]
}
```

The `matrix` is indexed `[day_of_week][hour]` where day 0 = Monday, hour 0 = midnight.

---

#### `GET /api/analytics/:stationId/depletion-rate`

**Response 200**
```json
{
  "success": true,
  "station_id": "STN-001",
  "litres_per_hour": 42.3,
  "tank_level_percent": 67.5
}
```

---

#### `GET /api/analytics/:stationId/time-to-empty`

**Response 200 — pump running**
```json
{
  "success": true,
  "station_id": "STN-001",
  "estimated_minutes": 187,
  "tank_level_percent": 67.5,
  "litres_per_hour": 42.3
}
```

**Response 200 — no consumption**
```json
{
  "success": true,
  "station_id": "STN-001",
  "estimated_minutes": null,
  "tank_level_percent": 67.5,
  "litres_per_hour": 0
}
```

---

### Extended Heartbeat Payload (Firmware → Backend)

`POST /api/stations/heartbeat` — Station auth

**Request (extended)**
```json
{
  "station_id": "STN-001",
  "status": "online",
  "tank_level": 67.5,
  "uptime_seconds": 86400,
  "firmware_version": "1.1.0",
  "pump_1_active": true,
  "pump_2_active": false,
  "pump_1_runtime_seconds": 45000,
  "pump_2_runtime_seconds": 29520
}
```

The backend converts `pump_N_runtime_seconds / 3600` to `pump_N_runtime_hours` before storing on the `stations` row.

---

## Data Flow Diagrams

### Flow 1: Operator Issues Pump Command

```
Operator (Dashboard)
  │
  │  POST /api/pumps/STN-001/command
  │  { pump_number: 1, action: "activate" }
  │  Authorization: Bearer <admin-jwt>
  ▼
Backend (pumpsController.js)
  │  1. Verify admin JWT
  │  2. Validate pump_number ∈ {1,2}, action ∈ {activate,deactivate}
  │  3. Check station exists
  │  4. INSERT pump_commands (status='pending')
  │  5. Return { id, created_at }
  ▼
SQLite pump_commands table
  │  status = 'pending'
  │
  │  (up to 10 seconds later)
  ▼
Firmware (pumpPoller.tick())
  │  GET /api/pumps/STN-001/pending
  │  X-Station-Id: STN-001
  │  X-Station-Secret: ***
  ▼
Backend (pumpsController.js)
  │  SELECT oldest pending → mark 'sent'
  │  Return { id, pump_number, action }
  ▼
Firmware
  │  Set GPIO 33 HIGH (activate Pump 1)
  │  POST /api/pumps/STN-001/ack
  │  { command_id: 42, pump_status_1: true, pump_status_2: false }
  ▼
Backend
  │  UPDATE pump_commands SET status='acknowledged'
  │  UPDATE stations SET pump_1_active=1, pump_2_active=0
  ▼
Dashboard (next 30-second React Query refresh)
  │  GET /api/pumps/STN-001/status
  │  PumpCard shows green "ON" badge
```

---

### Flow 2: Tank Level Simulation and History Recording

```
Firmware (every loop iteration)
  │
  ├─ TankSimulator::tick()
  │    IF pump_1_active OR pump_2_active:
  │      tank_level += PUMP_FILL_RATE_PERCENT_PER_SECOND * dt
  │      tank_level = min(100.0, tank_level)
  │    persist to NVS every 60 s
  │
  ├─ DispenseService::finishConfirm(actual_litres)
  │    TankSimulator::onDispenseComplete(actual_litres)
  │      tank_level -= (actual_litres / TANK_CAPACITY_LITRES) * 100
  │      tank_level = max(0.0, tank_level)
  │
  └─ Heartbeat::tick() (every 60 s)
       POST /api/stations/heartbeat
       { tank_level: 67.5, pump_1_active: true, ... }
       │
       ▼
     Backend (stationsController.heartbeat)
       UPDATE stations SET tank_level = 67.5
       INSERT tank_level_history (station_id, tank_level, recorded_at)
       │
       ▼
     Dashboard (GET /api/analytics/STN-001/tank-history)
       Recharts LineChart renders time-series
```

---

### Flow 3: AI Recommendation Request

```
Dashboard (React Query, 30 s interval)
  │
  │  GET /api/analytics/STN-001/recommendation
  ▼
Backend (analyticsController.js)
  │  1. Load station row: tank_level, pump_1_active, pump_2_active,
  │                        pump_1_runtime_hours, pump_2_runtime_hours
  │  2. Call recommendationEngine.recommend(station)
  │
  ▼
recommendationEngine.js (pure JS, no I/O)
  │
  │  if tank_level < 30 && !pump1Active && !pump2Active:
  │    pick pump with lower runtime_hours (default pump1 on tie)
  │    return { action: 'activate_pump_N', urgency: 'high', reason: '...' }
  │
  │  if tank_level < 30 && (pump1Active || pump2Active):
  │    return { action: 'no_action', urgency: 'low', reason: '...' }
  │
  │  if tank_level > 80 && (pump1Active || pump2Active):
  │    return { action: 'deactivate_pump', urgency: 'medium', reason: '...' }
  │
  │  else (30 <= tank_level <= 80):
  │    return { action: 'no_action', urgency: 'low', reason: '...' }
  │
  ▼
Backend returns recommendation JSON
  │
  ▼
Dashboard RecommendationPanel.jsx
  Renders urgency colour, reason text, Apply button (if action != no_action)
```

---

### Flow 4: Dashboard Auth Flow

```
Browser (page load)
  │
  ├─ AuthContext checks localStorage for JWT
  │
  ├─ JWT absent or expired?
  │    └─ Redirect to /login
  │
  └─ JWT present and valid?
       └─ Render DashboardPage / StationDetailPage

LoginPage
  │  POST /api/auth/login { phone, password }
  ▼
Backend (existing authController)
  │  Returns { token, user: { role, ... } }
  ▼
AuthContext
  │  IF role !== 'admin': show error, do NOT store JWT
  │  IF role === 'admin': localStorage.setItem('jwt', token)
  │                       navigate('/dashboard')

All API calls (api/client.js Axios interceptor)
  │  Reads JWT from localStorage
  │  Sets Authorization: Bearer <token>
  │
  │  On 401 response: clear JWT, redirect to /login
```

---

## AI Recommendation Algorithm

The recommendation engine is a pure JavaScript module with no database access — it receives a plain object and returns a recommendation object. This makes it trivially testable with property-based tests.

```js
// backend/src/services/recommendationEngine.js

const TANK_LOW_THRESHOLD  = 30;   // %
const TANK_HIGH_THRESHOLD = 80;   // %

/**
 * @param {object} station
 * @param {number} station.tank_level           - 0–100
 * @param {boolean} station.pump_1_active
 * @param {boolean} station.pump_2_active
 * @param {number} station.pump_1_runtime_hours
 * @param {number} station.pump_2_runtime_hours
 * @returns {{ action: string, pump_number: number|null, reason: string, urgency: string }}
 */
export function recommend(station) {
  const {
    tank_level,
    pump_1_active,
    pump_2_active,
    pump_1_runtime_hours,
    pump_2_runtime_hours,
  } = station;

  const anyPumpActive = pump_1_active || pump_2_active;

  if (tank_level < TANK_LOW_THRESHOLD) {
    if (!anyPumpActive) {
      // Pick pump with fewer runtime hours; default to pump 1 on tie
      const pumpNum = pump_1_runtime_hours <= pump_2_runtime_hours ? 1 : 2;
      const otherHours = pumpNum === 1 ? pump_2_runtime_hours : pump_1_runtime_hours;
      const thisHours  = pumpNum === 1 ? pump_1_runtime_hours : pump_2_runtime_hours;
      const reason = `Tank at ${tank_level.toFixed(0)}% — below ${TANK_LOW_THRESHOLD}% threshold. ` +
        `Pump ${pumpNum} has fewer runtime hours (${thisHours.toFixed(1)}h vs ${otherHours.toFixed(1)}h).`;
      return {
        action: `activate_pump_${pumpNum}`,
        pump_number: pumpNum,
        reason: reason.slice(0, 120),
        urgency: 'high',
      };
    }
    // One pump already running — no additional action needed
    return {
      action: 'no_action',
      pump_number: null,
      reason: `Tank at ${tank_level.toFixed(0)}% but a pump is already active. Monitoring.`.slice(0, 120),
      urgency: 'low',
    };
  }

  if (tank_level > TANK_HIGH_THRESHOLD && anyPumpActive) {
    const activePump = pump_1_active ? 1 : 2;
    return {
      action: 'deactivate_pump',
      pump_number: activePump,
      reason: `Tank at ${tank_level.toFixed(0)}% — above ${TANK_HIGH_THRESHOLD}% threshold. Deactivate Pump ${activePump}.`.slice(0, 120),
      urgency: 'medium',
    };
  }

  return {
    action: 'no_action',
    pump_number: null,
    reason: `Tank at ${tank_level.toFixed(0)}% — within normal range (${TANK_LOW_THRESHOLD}–${TANK_HIGH_THRESHOLD}%). No action needed.`.slice(0, 120),
    urgency: 'low',
  };
}
```

---

## Dashboard Component Hierarchy

```
App
├── AuthContext.Provider
│   ├── router.jsx (React Router v6)
│   │   ├── /login          → LoginPage
│   │   ├── /               → DashboardPage (ProtectedRoute)
│   │   │   ├── header (refresh indicator, logout)
│   │   │   ├── StationList
│   │   │   │   └── StationListItem × N
│   │   │   └── ToastNotification
│   │   └── /stations/:id   → StationDetailPage (ProtectedRoute)
│   │       ├── TankGauge
│   │       ├── PumpCard × 2
│   │       ├── RecommendationPanel
│   │       ├── DailyChart
│   │       └── HeatmapGrid
```

### Key Component Contracts

**`TankGauge`**
```jsx
// Props
{ level: number,        // 0–100
  isOffline: boolean,
  animationDuration?: number }  // default 600ms

// Renders: SVG arc gauge, colour-coded, numeric centre label
// Offline: grey overlay with "Offline" text
```

**`PumpCard`**
```jsx
// Props
{ stationId: string,
  pumpNumber: 1 | 2,
  isActive: boolean,
  runtimeHours: number,
  onToggle: (action: 'activate'|'deactivate') => Promise<void> }

// State: pending (bool) — disables toggle during in-flight request
// Error: inline error string below toggle button
```

**`RecommendationPanel`**
```jsx
// Props
{ stationId: string,
  recommendation: Recommendation }

// Urgency → background: high=red-100, medium=amber-100, low=gray-100
// Apply button hidden when action === 'no_action'
// Apply calls POST /api/pumps/:stationId/command with recommended pump/action
```

**`DailyChart`**
```jsx
// Props
{ data: DailyUsageRow[] }

// Recharts BarChart, x-axis: short day names, y-axis: litres
// Empty data: "No data" placeholder div
```

**`HeatmapGrid`**
```jsx
// Props
{ matrix: number[][] }  // [7][24]

// 7 rows (Mon–Sun) × 24 columns (00:00–23:00)
// Cell colour: white (0) → blue-900 (max), linear scale
// Empty data: "No data" placeholder
```

**`StationList`**
```jsx
// Props
{ stations: Station[] }

// Each row: id, name, location, status badge, tank_level%, last_seen
// Status badge colours: online=green, dispensing=blue, error=red, offline=gray
// Stale indicator: yellow badge when last_seen > 5 min and status != offline
// Click → navigate to /stations/:id
```

---

## Dashboard State Management

React Query is the single source of truth for all server state. No Redux or Zustand.

```js
// hooks/useStations.js
export function useStations() {
  return useQuery({
    queryKey: ['stations'],
    queryFn: () => stationsApi.list(),
    refetchInterval: 30_000,
    retry: Infinity,
    retryDelay: 30_000,
  });
}

// hooks/usePumpStatus.js
export function usePumpStatus(stationId) {
  return useQuery({
    queryKey: ['pumpStatus', stationId],
    queryFn: () => pumpsApi.getStatus(stationId),
    refetchInterval: 30_000,
  });
}

// hooks/useRecommendation.js
export function useRecommendation(stationId) {
  return useQuery({
    queryKey: ['recommendation', stationId],
    queryFn: () => analyticsApi.getRecommendation(stationId),
    refetchInterval: 30_000,
  });
}

// Pump toggle mutation — does NOT reset on auto-refresh
export function usePumpCommand(stationId) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ pump_number, action }) =>
      pumpsApi.sendCommand(stationId, { pump_number, action }),
    onSuccess: () => {
      // Invalidate pump status so next refetch picks up new state
      queryClient.invalidateQueries({ queryKey: ['pumpStatus', stationId] });
    },
  });
}
```

The `refetchInterval` on all queries drives the 30-second auto-refresh (Requirement 13). The mutation's `isPending` state drives the toggle button disabled state (Requirement 9.4), and it is independent of the query refetch cycle (Requirement 13.4).

---

## Firmware Tank Simulation Algorithm

```cpp
// tankSimulator.cpp

static float s_level = 100.0f;
static uint32_t s_lastTickMs = 0;
static uint32_t s_lastPersistMs = 0;

static constexpr uint32_t PERSIST_INTERVAL_MS = 60000UL;

void TankSimulator::begin() {
  nvs_handle_t h;
  if (nvs_open(NVS_NAMESPACE, NVS_READONLY, &h) == ESP_OK) {
    uint32_t raw = 0;
    if (nvs_get_u32(h, NVS_KEY, &raw) == ESP_OK) {
      // Store as fixed-point: level * 1000 to avoid float NVS issues
      s_level = raw / 1000.0f;
      s_level = fmaxf(0.0f, fminf(100.0f, s_level));
    }
    nvs_close(h);
  }
  s_lastTickMs = millis();
  s_lastPersistMs = millis();
}

void TankSimulator::tick() {
  uint32_t now = millis();
  float dtSeconds = (now - s_lastTickMs) / 1000.0f;
  s_lastTickMs = now;

  if (Pump::isActive(1) || Pump::isActive(2)) {
    s_level += PUMP_FILL_RATE_PERCENT_PER_SECOND * dtSeconds;
    if (s_level > 100.0f) s_level = 100.0f;
  }

  if (now - s_lastPersistMs >= PERSIST_INTERVAL_MS) {
    persist();
    s_lastPersistMs = now;
  }
}

void TankSimulator::onDispenseComplete(float actual_litres) {
  float drop = (actual_litres / TANK_CAPACITY_LITRES) * 100.0f;
  s_level -= drop;
  if (s_level < 0.0f) s_level = 0.0f;
  persist();  // persist immediately after dispense
}

float TankSimulator::getLevel() {
  return s_level;
}

void TankSimulator::persist() {
  nvs_handle_t h;
  if (nvs_open(NVS_NAMESPACE, NVS_READWRITE, &h) == ESP_OK) {
    nvs_set_u32(h, NVS_KEY, (uint32_t)(s_level * 1000.0f));
    nvs_commit(h);
    nvs_close(h);
  }
}
```

New constants in `config.h`:

```cpp
#define MAJISAFE_PUMP_1_PIN                33
#define MAJISAFE_PUMP_2_PIN                32
#define MAJISAFE_TANK_CAPACITY_LITRES      5000.0f
#define MAJISAFE_PUMP_FILL_RATE_PCT_PER_S  0.005f   // 0.5% per second = full in ~200s
#define MAJISAFE_PUMP_POLL_MS              10000UL
#define MAJISAFE_NVS_PERSIST_INTERVAL_MS   60000UL
```

---

## Firmware Pump Polling Loop

```cpp
// pumpPoller.cpp

static Sim800 *s_modem = nullptr;
static uint32_t s_nextPollMs = 0;

// Retry buffer for failed acks
static bool    s_pendingAck = false;
static int     s_pendingAckCommandId = -1;
static bool    s_pendingAckPump1 = false;
static bool    s_pendingAckPump2 = false;

void PumpPoller::begin(Sim800 *modem) {
  s_modem = modem;
  s_nextPollMs = millis() + MAJISAFE_PUMP_POLL_MS;
}

void PumpPoller::tick() {
  uint32_t now = millis();

  // Retry pending ack first
  if (s_pendingAck) {
    if (sendAck(s_pendingAckCommandId, s_pendingAckPump1, s_pendingAckPump2)) {
      s_pendingAck = false;
    }
    return;
  }

  if (now < s_nextPollMs) return;
  s_nextPollMs = now + MAJISAFE_PUMP_POLL_MS;

  // Poll for pending command
  String raw;
  if (!s_modem->httpGetPath(
        "/api/pumps/" MAJISAFE_STATION_ID "/pending", raw)) {
    return;  // GPRS unavailable; retry next cycle
  }

  int commandId = -1;
  int pumpNumber = -1;
  char action[16] = {};
  if (!parsePumpCommand(raw, commandId, pumpNumber, action)) {
    return;  // null command or parse error
  }

  // Execute GPIO
  if (pumpNumber == 1) {
    if (strcmp(action, "activate") == 0)   Pump::activate(1);
    else                                    Pump::deactivate(1);
  } else if (pumpNumber == 2) {
    if (strcmp(action, "activate") == 0)   Pump::activate(2);
    else                                    Pump::deactivate(2);
  }

  // Send ack
  bool p1 = Pump::isActive(1);
  bool p2 = Pump::isActive(2);
  if (!sendAck(commandId, p1, p2)) {
    // Store for retry
    s_pendingAck = true;
    s_pendingAckCommandId = commandId;
    s_pendingAckPump1 = p1;
    s_pendingAckPump2 = p2;
  }
}

static bool sendAck(int commandId, bool p1, bool p2) {
  char body[128];
  JsonDocument doc(96);
  doc["command_id"]    = commandId;
  doc["pump_status_1"] = p1;
  doc["pump_status_2"] = p2;
  serializeJson(doc, body, sizeof(body));
  String out;
  return s_modem->httpPostJson(
    "/api/pumps/" MAJISAFE_STATION_ID "/ack", body, out);
}
```

The `loop()` in `main.cpp` gains two new calls:

```cpp
PumpPoller::tick();
TankSimulator::tick();
Pump::tickRuntime();
```

And `DispenseService::finishConfirm()` gains one call:

```cpp
TankSimulator::onDispenseComplete(actual);
```

---

## Dashboard Deployment (`andasy.hcl`)

```hcl
app "majisafe-dashboard" {
  build {
    command = "npm install && npm run build"
    env = {
      VITE_API_BASE_URL = "https://majisafe-backend.andasy.dev"
    }
  }
  publish {
    directory = "dist"
  }
}
```

`vite.config.js`:

```js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': process.env.VITE_API_BASE_URL || 'http://localhost:3000',
    },
  },
});
```

`api/client.js`:

```js
import axios from 'axios';

const client = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '',
});

client.interceptors.request.use((config) => {
  const token = localStorage.getItem('jwt');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

client.interceptors.response.use(
  (r) => r,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('jwt');
      window.location.href = '/login';
    }
    return Promise.reject(err);
  }
);

export default client;
```
