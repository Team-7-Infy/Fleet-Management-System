# Driver Data Lifecycle & Retention

## Data Types & Persistence Locations

| Data | DB Table | Local Store | Retention Policy |
|------|----------|-------------|-----------------|
| Telemetry (location pings) | `telemetry_log` | In-memory buffer (offline queue) | **None defined** — table grows unbounded. Recommend: aggregate and purge after 90 days via scheduled cron. |
| Pre/post-trip inspections | `vehicle_inspections`, `inspection_items` | `UserDefaults.inspectedVehicles` (Set of trip IDs) | Indefinite for compliance. Local cache is device-only and lost on reinstall. |
| Driver schedules | `driver_schedules` | None | Retain 1 year past `end_time`, then archive. |
| Driver scores | `driver_scores` | None | Keep latest score per driver; recalculate after each completed trip. |
| Fuel history (requests) | None (local only) | `UserDefaults` (`local_fuel_history`) | Lost on reinstall or logout (audit finding L1). |
| Incidents | None (local only) | `UserDefaults` (`local_incidents`) | Lost on reinstall or logout (audit finding L1). |
| Pending post-trip inspection | `trips.post_trip_inspection_due_at` | `UserDefaults` (`pending_post_trip_inspection`) | Cleared on inspection completion. |
| Expense entries | `expense_entries` | None | Retain indefinitely for audit. |

## Security Gaps (Blocking)

The following tables currently have `grant all to anon` (audit finding C3) and/or no RLS (audit finding C2):

- `telemetry_log` — no RLS, no retention
- `vehicle_inspections`, `inspection_items` — grant all to anon, no RLS
- `driver_schedules` — grant all to anon, no RLS
- `driver_scores` — grant all to anon, no RLS
- `vehicle_documents` — grant all to anon, no RLS
- `expense_entries` — grant all to anon, no RLS
- `trips`, `drivers`, `users`, `vehicles`, `geofence`, `deviation_alert`, `route_waypoints` — no RLS

## Critical Gaps

### 1. Local-Only State (UserDefaults)
`inspectedVehicles`, `pendingPostTripInspection`, `fuelHistory`, and `incidents` are persisted only in `UserDefaults`. This means:
- Lost on reinstall
- Invisible to fleet managers
- Never cleared on logout → a subsequent user on a shared device inherits the previous driver's state (audit finding L1)

**Recommendation:** Migrate to server-side persistence:
- `fuelHistory` → `expense_entries` table (type = `fuel`)
- `incidents` → new `incidents` table
- `inspectedVehicles` → query `vehicle_inspections` table by trip_id
- `pendingPostTripInspection` → `trips.post_trip_inspection_due_at`

### 2. Offline Sync
`OfflineSyncManager`/`SyncTask` is referenced but non-functional (audit finding). Until resolved, any data written during offline periods is at risk of loss.

## Recommended Retention Policy

| Table | Retention | Action |
|-------|-----------|--------|
| `telemetry_log` | 90 days | Aggregate hourly averages, then delete raw pings |
| `vehicle_inspections` | Indefinite | Compliance requirement |
| `inspection_items` | Indefinite | Linked to inspections |
| `driver_schedules` | 1 year past `end_time` | Archive to cold storage |
| `driver_scores` | Keep latest only | Overwrite on recalculation |
| `expense_entries` | 7 years | Tax/audit compliance |
| `trips` | Indefinite | Core business record |
