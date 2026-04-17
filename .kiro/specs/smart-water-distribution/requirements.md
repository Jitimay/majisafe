# Requirements Document

## Introduction

The Smart Water Distribution Platform extends MajiSafe with pump control, simulated tank-level tracking, a rule-based AI recommendation engine, analytics, and a React web dashboard for station operators. It spans three components: the existing Node.js/Express backend (new routes and tables), a new React + Vite + Tailwind + Recharts dashboard deployed as a second Andasy app, and the TTGO T-Call ESP32 firmware (new pump relay control and tank simulation).

Tank level is **simulated** — there is no physical level sensor. The system estimates tank level by starting at 100 %, decreasing as water is dispensed (tracked via the flow sensor), and increasing while a pump is running. Pumps are controlled by the TTGO connected to an Arduino 8-relay module; relay 1 (GPIO 33) drives pump 1 and relay 2 (GPIO 32) drives pump 2.

---

## Glossary

- **Backend**: The Node.js/Express API running at `https://majisafe-backend.andasy.dev`.
- **Dashboard**: The React + Vite + Tailwind + Recharts web application in `dashboard/`, admin-only, deployed as a second Andasy app.
- **Firmware**: The C++/PlatformIO application running on the TTGO T-Call ESP32 at each dispensing station.
- **Station**: A physical water dispensing unit identified by a unique `station_id` (e.g., `STN-001`).
- **Pump**: A water supply pump connected to the relay module. Each station has Pump 1 (relay 1, GPIO 33) and Pump 2 (relay 2, GPIO 32).
- **Pump_Command**: A backend record instructing the Firmware to activate or deactivate a specific pump.
- **Tank_Level**: A simulated percentage (0–100 %) representing the estimated water level in the station's storage tank.
- **Tank_Level_History**: A time-series table of Tank_Level snapshots recorded by the Backend.
- **AI_Recommendation**: A rule-based suggestion produced by the Backend indicating which pump to activate and why.
- **Demand_Rate**: The rate of water consumption at a station, expressed in litres per hour, derived from confirmed dispense transactions.
- **Runtime_Hours**: The cumulative hours a pump has been in the active state, stored per pump per station.
- **Admin**: A user with `role = 'admin'` in the `users` table, authenticated via the existing JWT mechanism.
- **Operator**: A human using the Dashboard to monitor and control stations.
- **Heartbeat**: The periodic HTTP POST sent by the Firmware to `/api/stations/heartbeat` containing station telemetry.
- **JWT**: JSON Web Token used for authentication, issued by the existing `/api/auth` routes.
- **Relay_Module**: The Arduino 8-relay board connected to the TTGO T-Call ESP32 that physically switches pump power.

---

## Requirements

### Requirement 1: Pump Control API

**User Story:** As an Operator, I want to activate or deactivate individual pumps at any station from the Dashboard, so that I can manage water supply without visiting the site.

#### Acceptance Criteria

1. THE Backend SHALL expose a `POST /api/pumps/:stationId/command` endpoint that accepts `pump_number` (1 or 2) and `action` (`activate` or `deactivate`).
2. WHEN a valid pump command is received, THE Backend SHALL insert a record into the `pump_commands` table with status `pending` and return the command `id` and `created_at` timestamp.
3. IF the requesting user does not have `role = 'admin'`, THEN THE Backend SHALL return HTTP 403 with error code `FORBIDDEN`.
4. IF `pump_number` is not 1 or 2, THEN THE Backend SHALL return HTTP 400 with error code `INVALID_PUMP`.
5. IF `action` is not `activate` or `deactivate`, THEN THE Backend SHALL return HTTP 400 with error code `INVALID_ACTION`.
6. IF the `station_id` does not exist in the `stations` table, THEN THE Backend SHALL return HTTP 404 with error code `STATION_NOT_FOUND`.
7. THE Backend SHALL expose a `GET /api/pumps/:stationId/pending` endpoint that returns the oldest unacknowledged `pump_commands` record for that station and marks it `sent`.
8. THE Backend SHALL expose a `POST /api/pumps/:stationId/ack` endpoint that accepts `command_id` and `pump_status_1` and `pump_status_2` booleans, marks the command `acknowledged`, and updates the station's pump status fields.
9. THE Backend SHALL expose a `GET /api/pumps/:stationId/status` endpoint that returns the current `pump_1_active`, `pump_2_active`, `pump_1_runtime_hours`, and `pump_2_runtime_hours` for the station.

---

### Requirement 2: Tank Level History

**User Story:** As an Operator, I want to see how the tank level has changed over time, so that I can identify consumption patterns and plan pump schedules.

#### Acceptance Criteria

1. THE Backend SHALL maintain a `tank_level_history` table with columns `id`, `station_id`, `tank_level` (0–100), and `recorded_at` (UTC datetime).
2. WHEN the Firmware sends a Heartbeat containing a `tank_level` value, THE Backend SHALL insert a row into `tank_level_history` for that station.
3. THE Backend SHALL expose a `GET /api/analytics/:stationId/tank-history` endpoint that accepts optional `from` and `to` ISO-8601 query parameters and returns all matching `tank_level_history` rows ordered by `recorded_at` ascending.
4. IF `from` or `to` are provided but are not valid ISO-8601 datetime strings, THEN THE Backend SHALL return HTTP 400 with error code `INVALID_DATE`.
5. THE Backend SHALL retain `tank_level_history` rows for a minimum of 30 days before they are eligible for deletion.

---

### Requirement 3: Simulated Tank Level in Firmware

**User Story:** As an Operator, I want the station to report an estimated tank level, so that I can monitor water availability without installing a physical level sensor.

#### Acceptance Criteria

1. THE Firmware SHALL maintain a `tank_level_percent` variable initialised to 100.0 % on first boot.
2. WHEN a dispense transaction completes, THE Firmware SHALL decrease `tank_level_percent` by `(actual_litres / TANK_CAPACITY_LITRES) * 100`.
3. WHILE Pump 1 or Pump 2 is active, THE Firmware SHALL increase `tank_level_percent` by `PUMP_FILL_RATE_PERCENT_PER_SECOND` each second, capped at 100.0 %.
4. THE Firmware SHALL clamp `tank_level_percent` to the range [0.0, 100.0] at all times.
5. WHEN the Firmware sends a Heartbeat, THE Firmware SHALL include the current `tank_level_percent` value in the `tank_level` field.
6. THE Firmware SHALL persist `tank_level_percent` to non-volatile storage (NVS) so that a reboot does not reset the estimate to 100 %.

---

### Requirement 4: Pump Relay Control in Firmware

**User Story:** As an Operator, I want pump commands issued from the Dashboard to be executed by the station hardware, so that pumps are switched on or off reliably over GPRS.

#### Acceptance Criteria

1. THE Firmware SHALL poll `GET /api/pumps/:stationId/pending` every 10 seconds when not busy dispensing.
2. WHEN a `pump_commands` record is returned, THE Firmware SHALL set GPIO 33 HIGH to activate Pump 1 or LOW to deactivate Pump 1, and GPIO 32 HIGH to activate Pump 2 or LOW to deactivate Pump 2, according to the command.
3. WHEN a pump command has been executed, THE Firmware SHALL POST to `/api/pumps/:stationId/ack` with the `command_id` and the current boolean state of both pumps.
4. THE Firmware SHALL include `pump_1_active` and `pump_2_active` boolean fields in every Heartbeat payload.
5. WHILE a pump is active, THE Firmware SHALL accumulate elapsed time in seconds and report `pump_1_runtime_seconds` and `pump_2_runtime_seconds` in the Heartbeat payload.
6. IF the GPRS connection is unavailable when a pump command acknowledgement is due, THEN THE Firmware SHALL retry the acknowledgement on the next successful connection.

---

### Requirement 5: AI Recommendation Engine

**User Story:** As an Operator, I want the system to suggest which pump to run based on current tank level and demand, so that I can act quickly without manually analysing data.

#### Acceptance Criteria

1. THE Backend SHALL expose a `GET /api/analytics/:stationId/recommendation` endpoint that returns a recommendation object containing `action` (`activate_pump_1`, `activate_pump_2`, `deactivate_pump`, or `no_action`), `pump_number` (1, 2, or null), `reason` (human-readable string), and `urgency` (`high`, `medium`, or `low`).
2. WHEN `tank_level` is below 30 % and no pump is active, THE Backend SHALL recommend activating the pump with fewer `runtime_hours`.
3. WHEN `tank_level` is below 30 % and one pump is already active, THE Backend SHALL recommend no additional action with `urgency = 'low'`.
4. WHEN `tank_level` is above 80 % and a pump is active, THE Backend SHALL recommend deactivating the active pump.
5. WHEN `tank_level` is between 30 % and 80 %, THE Backend SHALL return `action = 'no_action'` with `urgency = 'low'`.
6. WHEN both pumps have equal `runtime_hours`, THE Backend SHALL recommend Pump 1 as the default.
7. THE Backend SHALL include a `reason` string of no more than 120 characters describing the recommendation in plain English.

---

### Requirement 6: Analytics Endpoints

**User Story:** As an Operator, I want to view daily consumption totals, hourly demand patterns, tank depletion rate, and estimated time to empty, so that I can plan maintenance and supply schedules.

#### Acceptance Criteria

1. THE Backend SHALL expose a `GET /api/analytics/:stationId/daily-usage` endpoint that accepts optional `days` (integer, default 7, max 90) and returns an array of `{ date, total_litres }` objects for the requested period.
2. THE Backend SHALL expose a `GET /api/analytics/:stationId/hourly-heatmap` endpoint that returns a 7 × 24 matrix of average litres dispensed per hour-of-day per day-of-week, computed from the last 30 days of confirmed transactions.
3. THE Backend SHALL expose a `GET /api/analytics/:stationId/depletion-rate` endpoint that returns `litres_per_hour` (average consumption rate over the last 24 hours) and `tank_level_percent` (current value from the `stations` table).
4. THE Backend SHALL expose a `GET /api/analytics/:stationId/time-to-empty` endpoint that returns `estimated_minutes` computed as `(tank_level_percent / 100 * TANK_CAPACITY_LITRES) / litres_per_hour * 60`, or `null` when `litres_per_hour` is 0.
5. IF `days` is less than 1 or greater than 90, THEN THE Backend SHALL return HTTP 400 with error code `INVALID_RANGE`.
6. ALL analytics endpoints SHALL require a valid Admin JWT in the `Authorization: Bearer` header.
7. WHEN no confirmed transactions exist for the requested period, THE Backend SHALL return empty arrays or zero values rather than an error.

---

### Requirement 7: Admin Authentication for Dashboard

**User Story:** As an Admin, I want to log in to the Dashboard using my existing credentials, so that I do not need a separate account.

#### Acceptance Criteria

1. THE Dashboard SHALL present a login form accepting `phone` and `password` fields.
2. WHEN valid Admin credentials are submitted, THE Dashboard SHALL call `POST /api/auth/login`, store the returned JWT in `localStorage`, and redirect to the main dashboard view.
3. IF the login response contains `role` other than `admin`, THEN THE Dashboard SHALL display the message "Access restricted to administrators" and SHALL NOT store the JWT.
4. IF the JWT stored in `localStorage` is absent or expired on page load, THEN THE Dashboard SHALL redirect the user to the login form.
5. THE Dashboard SHALL attach the JWT as `Authorization: Bearer <token>` on all API requests.
6. WHEN the user clicks "Logout", THE Dashboard SHALL remove the JWT from `localStorage` and redirect to the login form.

---

### Requirement 8: Live Tank Level Gauges

**User Story:** As an Operator, I want to see animated circular gauges showing the current tank level for each station, so that I can assess water availability at a glance.

#### Acceptance Criteria

1. THE Dashboard SHALL display one circular gauge per station showing `tank_level` as a percentage.
2. WHEN `tank_level` changes between auto-refresh cycles, THE Dashboard SHALL animate the gauge transition over 600 ms.
3. THE Dashboard SHALL colour the gauge arc green when `tank_level` ≥ 50 %, amber when `tank_level` is between 20 % and 49 %, and red when `tank_level` < 20 %.
4. THE Dashboard SHALL display the numeric percentage value in the centre of each gauge.
5. WHEN a station's `status` is `offline`, THE Dashboard SHALL overlay the gauge with a grey "Offline" indicator.

---

### Requirement 9: Pump Status Cards with Toggle Controls

**User Story:** As an Operator, I want to see the current state of each pump and toggle it on or off from the Dashboard, so that I can control water supply remotely.

#### Acceptance Criteria

1. THE Dashboard SHALL display two pump status cards per station labelled "Pump 1" and "Pump 2".
2. WHEN `pump_1_active` is true, THE Dashboard SHALL show the Pump 1 card with a green "ON" badge; WHEN false, THE Dashboard SHALL show a grey "OFF" badge.
3. THE Dashboard SHALL include an ON/OFF toggle button on each pump card.
4. WHEN an Operator clicks the toggle button, THE Dashboard SHALL call `POST /api/pumps/:stationId/command` with the appropriate `pump_number` and `action`, then disable the button until the next auto-refresh confirms the new state.
5. IF the pump command API call fails, THEN THE Dashboard SHALL display an inline error message on the affected card and re-enable the toggle button.
6. THE Dashboard SHALL display `pump_1_runtime_hours` and `pump_2_runtime_hours` on the respective cards, formatted as "Xh Ym".

---

### Requirement 10: AI Recommendation Panel

**User Story:** As an Operator, I want to see a clear recommendation panel telling me which pump to run and why, so that I can act on the system's advice without interpreting raw data.

#### Acceptance Criteria

1. THE Dashboard SHALL display one AI Recommendation panel per station showing the `reason` string returned by `GET /api/analytics/:stationId/recommendation`.
2. WHEN `urgency` is `high`, THE Dashboard SHALL render the panel with a red background and a warning icon.
3. WHEN `urgency` is `medium`, THE Dashboard SHALL render the panel with an amber background.
4. WHEN `urgency` is `low` or `action` is `no_action`, THE Dashboard SHALL render the panel with a neutral grey background.
5. THE Dashboard SHALL include a one-click "Apply" button on the panel that, when clicked, sends the recommended pump command directly via `POST /api/pumps/:stationId/command`.
6. WHEN `action` is `no_action`, THE Dashboard SHALL hide the "Apply" button.

---

### Requirement 11: Usage Charts

**User Story:** As an Operator, I want to view daily consumption bar charts and an hourly demand heatmap, so that I can identify peak usage times and plan accordingly.

#### Acceptance Criteria

1. THE Dashboard SHALL render a bar chart of daily water consumption (litres) for the last 7 days using data from `GET /api/analytics/:stationId/daily-usage`.
2. THE Dashboard SHALL render a heatmap grid (7 days × 24 hours) of average demand using data from `GET /api/analytics/:stationId/hourly-heatmap`, with darker cells indicating higher demand.
3. WHEN no data is available for a period, THE Dashboard SHALL display a "No data" placeholder instead of an empty chart.
4. THE Dashboard SHALL label the bar chart x-axis with short day names (Mon, Tue, …) and the y-axis with litre values.
5. THE Dashboard SHALL label the heatmap columns with hour labels (00:00–23:00) and rows with day-of-week labels.

---

### Requirement 12: Station List with Health Status

**User Story:** As an Operator, I want a station list showing each station's health status, so that I can quickly identify stations that need attention.

#### Acceptance Criteria

1. THE Dashboard SHALL display a list of all stations returned by `GET /api/stations`.
2. EACH station entry SHALL show `id`, `name`, `location`, `status`, `tank_level`, and `last_seen`.
3. THE Dashboard SHALL colour-code the status badge: green for `online`, blue for `dispensing`, red for `error`, and grey for `offline`.
4. WHEN `last_seen` is more than 5 minutes ago and `status` is not `offline`, THE Dashboard SHALL display a yellow "Stale" indicator next to the station entry.
5. WHEN an Operator clicks a station entry, THE Dashboard SHALL navigate to the station detail view showing gauges, pump cards, recommendation panel, and charts for that station.

---

### Requirement 13: Auto-Refresh

**User Story:** As an Operator, I want the Dashboard to refresh automatically, so that I always see current data without manually reloading the page.

#### Acceptance Criteria

1. THE Dashboard SHALL refresh all station data, pump statuses, tank levels, and recommendations every 30 seconds.
2. WHEN a refresh is in progress, THE Dashboard SHALL display a subtle loading indicator in the header.
3. WHEN a refresh fails due to a network error, THE Dashboard SHALL display a non-blocking toast notification "Connection lost — retrying…" and continue retrying every 30 seconds.
4. THE Dashboard SHALL NOT reset user-initiated actions (e.g., a pending pump toggle) during an auto-refresh cycle.

---

### Requirement 14: Responsive Design

**User Story:** As an Operator using a tablet in the field, I want the Dashboard to be usable on a tablet screen, so that I can monitor and control stations without a desktop computer.

#### Acceptance Criteria

1. THE Dashboard SHALL render correctly on screens with a minimum width of 768 px (tablet portrait).
2. THE Dashboard SHALL use a single-column layout on screens narrower than 1024 px and a multi-column layout on screens 1024 px and wider.
3. ALL interactive controls (toggle buttons, Apply button, login form) SHALL have a minimum touch target size of 44 × 44 px.
4. THE Dashboard SHALL not require horizontal scrolling on a 768 px wide viewport.

---

### Requirement 15: Dashboard Deployment

**User Story:** As a system administrator, I want the Dashboard to be deployable to Andasy as a second app, so that it is accessible from the internet alongside the backend.

#### Acceptance Criteria

1. THE Dashboard SHALL be buildable with `npm run build` producing a static `dist/` directory.
2. THE Dashboard project SHALL include an `andasy.hcl` configuration file that defines the app name, build command, and publish directory.
3. THE Dashboard SHALL read the backend API base URL from a `VITE_API_BASE_URL` environment variable so that it can be configured at build time without code changes.
4. THE Dashboard SHALL serve correctly when hosted at a sub-path or root path as configured in `andasy.hcl`.
