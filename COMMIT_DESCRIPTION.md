# Version Commit Description

Baseline commit reviewed:

- `e184c21` - Merge remote-tracking branch `origin/production` into `DriverScoreUpdation`

## Summary

This version adds database-backed fuel logging, trip timing enforcement, inspection-driven trip states, and fuel-efficiency reporting across the driver and fleet manager experience. It also adds shared image caching for profile/avatar loading and updates trip/detail screens to surface no-show, rejection, overdue inspection, fuel consumption, and inspection failure context.

## Major Changes

- Added a `fuel_logs` database-backed workflow with a new `FuelLog` model, `FuelService`, and `FuelServiceProtocol`.
- Wired `FuelService` and Supabase access into `AppServices` and `LocalDataStore`.
- Replaced the previous standalone fuel request flow with trip-scoped fuel logging from `TripFuelHistoryView`.
- Added support for loading and saving driver fuel history through Supabase, with local fallback/error state.
- Added trip fields for cancellation reason, post-trip flagged state, fuel consumed, and fuel-consumption warning state.
- Added vehicle fuel capacity fields for liquid fuel and EV battery capacity.
- Extended notification rendering for pre-trip no-show alerts.
- Changed trip cancellation lock timing from 3 hours to 24 hours.
- Added post-trip and pre-trip inspection timing behavior, including trip-specific inspection markers keyed by trip and vehicle.
- Updated trip detail and completed trip screens to show rejection-pending context, missed pre-trip cancellation details, inspection failures, fuel logs, mileage, and fuel-consumption warnings.
- Updated inspection completion flow to persist state after service calls and require a fresh pre-trip inspection after replacement vehicle assignment.
- Added fuel-efficiency analytics to fleet manager reports and driver performance metrics.
- Added shared `ImageCache` and `CachedAsyncImage`, then used cached image loading in profile/avatar surfaces.
- Updated vehicle manager forms and views for fuel-capacity-related fields.

## Database Migration

Added `FMS/Database/migrations/20260709_fuel_logging_and_scheduling_timeout.sql` with:

- `fuel_logs` table, indexes, and RLS policies.
- Fuel-cost synchronization from approved fuel logs into trips.
- `trips.cancellation_reason` and `trips.post_trip_flagged`.
- Revised vehicle status sync behavior around completed trips and post-trip inspection deadlines.
- Pre-trip no-show processor that cancels stale trips, penalizes driver scores, sends fleet manager notifications, and refreshes vehicle/driver status.
- Post-trip overdue processor that flags overdue inspections, penalizes driver scores, sends fleet manager notifications, and releases vehicle status.
- Cron schedules for pre-trip no-show and post-trip overdue checks.

## Removed/Replaced

- Removed the old `FuelRequestView`.
- Removed the old `FuelViewModel`.
- Removed local-only fuel request status handling from `FuelRecord`.

## Commit Message

```text
Add fuel logging and trip inspection timing workflows

- add fuel log persistence, service wiring, and database migration
- enforce trip-scoped fuel logging windows and display fuel history
- surface no-show, rejected, and overdue inspection states in trip UI
- add fuel efficiency metrics for driver performance and fleet reports
- introduce cached async image loading for avatars and profile surfaces
```
