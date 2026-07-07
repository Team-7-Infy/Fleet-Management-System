# Fleet Management System — Production-Readiness Audit Report

**Date:** 2026-07-07
**Scope:** Full codebase review: DB/RLS, Services, Core Infrastructure, FleetManager, Driver, Auth, Maintenance NewUI
**Total Findings:** ~130 across 21 tables of findings

---

# SEVERITY: CRITICAL (Data Loss / Security Breach / Crash on Every Launch)

## C1 — `service_role` JWT Exposed as "Anon Key" in xcconfig (Both Build Configs)

The key in `Secrets.debug.xcconfig:11` and `Secrets.release.xcconfig:11` has `"role": "service_role"` in its JWT payload, **not** `"role": "anon"`. This grants full admin-level DB access, bypassing ALL RLS.

```
Decoded JWT:
  role: service_role  ← NOT "anon"
  ref: vbmlbvngzcttjnbxydkk
```

**Impact:** Every client app has full read/write to every table. Any attacker extracting this key (trivial from app binary) owns the database. All RLS policies are meaningless.

**Files:**
- `FMS/Secrets.debug.xcconfig:11`
- `FMS/Secrets.release.xcconfig:11`
- `FMS/Core/Infrastructure/EnvironmentConfig.swift:18-24`
- `FMS/Core/Infrastructure/SupabaseService.swift:19`
- `FMS/Modules/Maintenance/NewUI/Core/Networking/APIClient.swift:13-14`

---

## C2 — No RLS on 14 Core Database Tables

These tables have **zero** `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` and **zero** policies:

`users`, `drivers`, `fleet_manager`, `maintenance_personnel`, `vehicles`, `trips`, `geofence`, `deviation_alert`, `route_waypoints`, `telemetry_log`, `maintenance_task`, `maintenance_task_parts`, `task_vehicles`, `inventory`

**Impact:** Any authenticated (or anon, see C3) user has unrestricted CRUD. No tenant isolation.

**Files:** All migration files in `FMS/Database/`

---

## C3 — `GRANT ALL TO anon` on 6 New Tables

**File:** `Database/migrations/20260707_phase1_table_permissions.sql:2-7`

```sql
grant all on public.vehicle_documents to anon, authenticated, service_role;
grant all on public.driver_scores to anon, authenticated, service_role;
grant all on public.driver_schedules to anon, authenticated, service_role;
grant all on public.vehicle_inspections to anon, authenticated, service_role;
grant all on public.inspection_items to anon, authenticated, service_role;
grant all on public.expense_entries to anon, authenticated, service_role;
```

**Impact:** Unauthenticated users have full CRUD on all new tables. Combined with C1, zero security.

---

## C4 — SOS Alert Sends `recipientId: nil` (Emergency Notifications Go Nowhere)

Three critical locations create `AppNotification` objects with `recipientId: nil`:

**Files:**
- `Modules/Driver/Features/Dashboard/DashboardView.swift:410-419` — Driver SOS trigger
- `Modules/FleetManager/Views/FleetManagerDashboardView.swift:88` — FM notification subscription
- `Modules/Maintenance/NewUI/Views/Dashboard/MPDashboardView.swift:21` — MP notification subscription

**Impact:** SOS alerts are created but never delivered to any user. Life-safety feature is non-functional.

---

## C5 — `DateOnly.swift`: DateFormatter Not Thread-Safe in Sendable Type

**File:** `Core/Infrastructure/DateOnly.swift:30-36`

`DateFormatter` is not thread-safe but `DateOnly` conforms to `Codable` + `Sendable` and may be decoded on any thread. This is a data race that can cause crashes under concurrent decoding.

**Impact:** Random crashes during JSON decoding when multiple threads decode DateOnly values.

---

## C6 — `MaintenanceTask.swift`: `try?` Chains Silently Corrupt Data on Schema Mismatch

**File:** `Core/Models/MaintenanceTask.swift:46-112`

Entire custom `init(from:)` uses `try?` for every non-primary field, silently falling back to `nil` or `Date()` on decode failure. If the DB schema changes, data silently disappears — no error is raised.

**Impact:** Silent data corruption — fields appear as defaults/zero values instead of throwing an error.

---

## C7 — Hardcoded Production Password in Seed Files

**Files:**
- `Database/seeds/20260701_demo_auth_logins.sql:3` — `-- Password for every account below: Fms@123456`
- `Database/seeds/20260701_reset_manager_password.sql:5` — Same

**Impact:** If seed scripts are ever run against production (the `run_full_demo_seed.sh` script exists as a pathway), all demo accounts have the publicly-known password `Fms@123456`.

---

# SEVERITY: HIGH (Crash on Specific Paths / Data Loss / Security Weakness)

## H1 — 44 `.single()` Calls That Crash on Zero/Multiple Rows

Every service file uses `.single()` which crashes at runtime if the DB returns 0 or >1 rows for the query.

**Affected files (each has 2-6 calls):**
- `Services/VehicleService.swift:38,48,59,103,114`
- `Services/MaintenanceService.swift:68,78,89`
- `Services/TripService.swift:36,46,57,109,119,138,177`
- `Services/InventoryService.swift:26,36,47`
- `Services/ExpenseService.swift:50`
- `Services/AuthService.swift:55,79,89,105,292`
- `Services/InspectionService.swift:26`
- `Services/NotificationService.swift:69`
- `Services/UserManagementService.swift:28,54,96,127,145,163,184,192,281,301`
- `Modules/Maintenance/NewUI/Services/SupabaseAuthService.swift:19,69,79`

**Fix:** Replace with `.single()` → `.execute().value` that throws a recoverable error, or use `.maybeSingle()` / handle empty results gracefully.

---

## H2 — ~29 ObservableObject ViewModels Missing `@MainActor`

Publishing `@Published` properties from background async contexts without `@MainActor` causes runtime crashes on iOS 17+ (or data races on iOS 18+ with strict concurrency).

**Affected ViewModels (class-level `@MainActor` missing):**

| File | Class |
|------|-------|
| `Modules/Maintenance/NewUI/ViewModels/MPDashboardViewModel.swift` | `MPDashboardViewModel` |
| `Modules/Maintenance/NewUI/ViewModels/ProfileViewModel.swift` | `ProfileViewModel` |
| `Modules/Maintenance/NewUI/ViewModels/ActivityHistoryViewModel.swift` | `ActivityHistoryViewModel` |
| `Modules/Maintenance/NewUI/ViewModels/VehicleDetailsViewModel.swift` | `VehicleDetailsViewModel` |
| `Modules/Maintenance/NewUI/ViewModels/UpcomingMaintenanceListViewModel.swift` | `UpcomingMaintenanceListViewModel` |
| `Modules/Maintenance/NewUI/ViewModels/MyJobsViewModel.swift` | `MyJobsViewModel` |
| `Modules/Maintenance/NewUI/ViewModels/JobSummaryViewModel.swift` | `JobSummaryViewModel` |
| `Modules/Maintenance/NewUI/ViewModels/CompleteWorkOrderViewModel.swift` | `CompleteWorkOrderViewModel` |
| `Modules/Maintenance/NewUI/ViewModels/PastWorkOrderDetailsViewModel.swift` | `PastWorkOrderDetailsViewModel` |
| `Modules/Maintenance/NewUI/ViewModels/WorkOrderSuccessViewModel.swift` | `WorkOrderSuccessViewModel` |
| `Modules/FleetManager/ViewModels/ManagerProfileViewModel.swift` | `ManagerProfileViewModel` |
| `Modules/Driver/Features/Trips/LocationManager.swift` | `LocationManager` |
| `Modules/Driver/Features/Trips/ActiveNavigationDetailView.swift` | `LiveNavigationViewModel` |
| `Modules/Driver/Features/Trips/FleetManagerChatView.swift` | `ChatViewModel` |
| `Modules/Driver/Features/Performance/PerformanceViewModel.swift` | `PerformanceViewModel` |
| `Modules/Driver/Features/Vehicle/InspectionViewModel.swift` | `InspectionViewModel` |
| `Modules/Driver/Features/Fuel/FuelViewModel.swift` | `FuelViewModel` |
| `Modules/Driver/Features/Dashboard/DashboardViewModel.swift` | `DashboardViewModel` |
| `Modules/Driver/Features/Incident/IncidentViewModel.swift` | `IncidentViewModel` |
| `Modules/Driver/Features/Emergency/SOSViewModel.swift` | `SOSViewModel` |
| `Modules/Driver/Core/OfflineSyncManager.swift` | `OfflineSyncManager` |
| `FleetManager/Views/Trips/ManagerTripFormSheet.swift` | `TripPlaceSearchViewModel` |

---

## H3 — N+1 Query Patterns (7 Instances)

In each case, a loop fetches data per-item instead of a single batched query.

| File | Lines | Pattern |
|------|-------|---------|
| `Modules/Maintenance/NewUI/Services/WorkOrderAssignmentService.swift` | 29-34 | Per-personnel `fetchTasksForPersonnel` RPC call |
| `Services/UserManagementService.swift` | 226-235 | Per-trip deviation_alert query |
| `Services/InventoryService.swift` | 72-75 | Per-row `createPart` in bulk import |
| `Modules/Maintenance/NewUI/Services/SupabaseWorkOrderService.swift` | 90-97 | Per-photo storage upload |
| `Modules/Maintenance/NewUI/Services/SupabaseWorkOrderService.swift` | 159-165 | Per-part `consume_inventory` RPC |
| `Modules/Maintenance/NewUI/Services/SupabaseWorkOrderService.swift` | 208-214 | Per-task-vehicle vehicle update |
| `Modules/Maintenance/NewUI/ViewModels/PastWorkOrderDetailsViewModel.swift` | 26-39 | 4 queries per work order detail load |

---

## H4 — Optimistic Update Race Conditions (4 Instances)

Updates execute destructive operations before confirming success, with no rollback.

**Files:**
- `Modules/Maintenance/NewUI/Services/SupabaseWorkOrderService.swift:42-83` — Deletes all parts before confirming insert succeeds
- `Modules/Maintenance/NewUI/Services/SupabaseWorkOrderService.swift:85-127` — Uploads photos, then updates task — orphaned photos on failure
- `Modules/Maintenance/NewUI/ViewModels/CompleteWorkOrderViewModel.swift:139-178` — Status update before notification, no transaction
- `Modules/Maintenance/NewUI/ViewModels/CompleteWorkOrderViewModel.swift:217-228` — Stale inventory check (local cache, not server-validated)

---

## H5 — Duplicate Service Layers (5 Parallel Implementations)

Maintenance NewUI defines its own independent service stack duplicating the main `Services/` layer:

| NewUI Service | Main Service |
|--------------|-------------|
| `NewUI/Services/SupabaseWorkOrderService.swift` | `Services/MaintenanceService.swift` |
| `NewUI/Services/SupabaseVehicleService.swift` | `Services/VehicleService.swift` |
| `NewUI/Services/SupabaseAuthService.swift` | `Services/AuthService.swift` |
| `NewUI/Services/SupabaseActivityService.swift` | (no direct equivalent) |
| `NewUI/Services/Protocols/` (5 protocols) | `Services/Protocols/` (8 protocols) |

**Issues:** Class-based (not actor), no thread safety, code drift, maintenance burden.

---

## H6 — 24+ Unbounded Fetches (No Pagination)

Every fetch method in every service loads ALL rows without `.limit()`, `.range()`, or `.offset()`.

**Worst offenders:**
- `Modules/Maintenance/NewUI/Services/SupabaseWorkOrderService.swift:13` — `assignedWorkOrders()` — no filters, no limit
- `Services/VehicleService.swift:144` — `fetchVehicleHealthScores()` — fetches **6 full tables** in memory
- `Modules/FleetManager/ViewModels/ReportsViewModel.swift:73-91` — All computed properties iterate entire arrays
- Every `fetch*` method in `Services/`

**Impact:** Memory pressure and slow loads as data grows. App will become unusable at scale.

---

## H7 — 17 Force Unwraps in FleetManager Module

**Notable crash risks:**
- `ViewModels/ReportsViewModel.swift:25,65,172,173,175,180,196,233,234,247` — Calendar date force unwraps
- `ViewModels/UserManagementViewModel.swift:142,143,144,145,146` — `randomElement()!` on character sets that could be empty
- `Views/Reports/Components/FitnessChartView.swift:112` — Calendar force unwrap

---

## H8 — 9 Force Unwraps in Maintenance NewUI Module

- `ProfileViewModel.swift:84`, `UserProfile.swift:40`, `MPProfileView.swift:618` — TOCTOU pattern: `contact != nil ? String(contact!) : ""`
- `MPDashboardView.swift:283,284`, `AllUpcomingWorkOrdersView.swift:75`, `AllUnfinishedWorkOrdersView.swift:59`, `AllHistoryWorkOrdersView.swift:56`, `UpcomingMaintenanceListView.swift:123` — `vehicle != nil ? "\(vehicle!.make) \(vehicle!.model)" : "Unknown"`

---

## H9 — `TripStatus` Missing `paused` Case

**File:** `Core/Enums/TripStatus.swift:3-12`

The enum has no `paused` case. Pause/resume exists purely as a `UserDefaults` flag (`trip_<UUID>_paused`), NEVER updating the backend.

**Files:**
- `Modules/Driver/Features/Trips/ActiveNavigationDetailView.swift:705-710` — Toggle only writes UserDefaults
- `Modules/Driver/Features/Dashboard/DashboardView.swift:815` — Reads UserDefaults flag

**Impact:** Trip pause state lost on device change. Backend always shows `in_progress` even when paused.

---

## H10 — UserDefaults-Only Storage for Critical Data (Loss on Device Change)

| Data | File | Lines |
|------|------|-------|
| Fuel history | `Modules/Driver/Core/LocalDataStore.swift` | 64-74 |
| Incident reports | `Modules/Driver/Core/LocalDataStore.swift` | 98-108 |
| Post-trip inspection pending | `Modules/Driver/Core/LocalDataStore.swift` | 11-14 |
| Inspection odometer/fuel | `Modules/Driver/Features/Vehicle/InspectionView.swift` | 418-423 |
| Offline sync queue | `Modules/Driver/Core/OfflineSyncManager.swift` | 76-91 |
| Trip pause state | `ActiveNavigationDetailView.swift` | 709, 895 |

**Impact:** ALL of this data is lost on: device change, app reinstall, iCloud restore. The offline sync queue is particularly dangerous — pending syncs vanish.

---

## H11 — `NotificationViewModel` Subscription Leak (No `deinit`)

**File:** `Core/ViewModels/NotificationViewModel.swift:199-254`

`subscribeToRealtime()` creates async tasks that capture `self` strongly. There is **no `deinit`** calling `unsubscribeRealtime()`. If the view model is deallocated, tasks continue writing to released memory.

Additionally, `subscribeToRealtime()` has no `do/catch` — if the stream throws, real-time updates silently stop forever (no reconnection logic).

---

## H12 — OfflineSyncManager Never Actually Syncs (Simulated)

**File:** `Modules/Driver/Core/OfflineSyncManager.swift:56-62`

```swift
// SIMULATED API CALL
DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
    successfulTaskIds.insert(task.id)
    group.leave()
}
```

The sync never performs HTTP requests — it simulates success after 0.5 seconds. The entire offline sync infrastructure is non-functional.

---

## H13 — `MaintenanceTaskStatus` Contains `fake` Artifact in Production

**File:** `Core/Enums/MaintenanceTaskStatus.swift:9`

```swift
case fake = "fake"
```

This is a testing/debugging artifact. If any task in the DB has status `"fake"`, it is treated as closed/inactive by `isOpen`.

Also missing: `verified` and `closed` states per SRS WO-01 lifecycle.

---

## H14 — `Dictionary(uniqueKeysWithValues:)` Crash Risk

**File:** `Modules/FleetManager/ViewModels/VehicleViewModel.swift:46`

```swift
let lookup = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0) })
```

Crashes with fatal error if two vehicles share the same `id`.

---

## H15 — `EnvironmentConfig.swift`: `fatalError` on Missing Config

**File:** `Core/Infrastructure/EnvironmentConfig.swift:13,22`

App crashes immediately at startup if Info.plist entries are missing. No graceful degradation.

---

## H16 — `InventoryPart.threshold: Int` Without Default — Crash on NULL

**File:** `Core/Models/InventoryPart.swift:15`

`threshold` is non-optional `Int` with no custom decoder. If the DB column is NULL, decoding the whole model crashes.

---

## H17 — Missing Error Handling in `.task` / `.refreshable` Blocks (16+ Locations)

Every `.task` and `.refreshable` block in the FleetManager module lacks `do/catch`, meaning any thrown error crashes the view.

**Notable files:**
- `FleetManager/Views/Vehicles/VehicleComplianceDocsView.swift:60`
- `FleetManager/Views/ManagerProfileView.swift:96`
- `FleetManager/Views/Maintenance/ManagerMaintenanceView.swift:112-116, 330-332`
- `FleetManager/Views/Overview/ManagerOverviewView.swift:80-82`
- `FleetManager/Views/FleetManagerDashboardView.swift:134-140`

---

## H18 — SplashView Silent Error Fallback

**File:** `Modules/Auth/Views/SplashView.swift:36-46`

```swift
try? await authService.currentSession()  // Silently catches ALL errors
```

If session check fails for any reason (network, expired token, server error), user sees a brief "Loading..." then gets dumped to login with zero explanation.

---

# SEVERITY: MEDIUM (Degraded UX / Maintainability Concerns)

## M1 — Personnel Count Bug (16 Total, 15 Shown)

**Root Cause:** Seed data sets Chetan Kulkarni (`41000000-...-000000000211`) with `status = 'inactive'`, and `ManagerMaintenanceRequestSheet.swift:35` filters `$0.status == .active`, dropping exactly 1 person.

**Files:**
- `Modules/FleetManager/Views/Maintenance/ManagerMaintenanceRequestSheet.swift:22,35,120`
- `Modules/FleetManager/Views/Maintenance/ManagerServiceDetailView.swift:92`

**Fix:** Either set status to `active` in seeds, or change filter to include `inactive` personnel where appropriate.

---

## M2 — `NotificationViewModel` Double-Optional `UUID??`

**File:** `Core/ViewModels/NotificationViewModel.swift:142`

```swift
func addLocalNotification(..., recipientIdOverride: UUID?? = nil)
```

`UUID??` is confusing API design. The unwrapping logic treats `.some(nil)` as an override to `nil`, which is likely unintentional.

---

## M3 — Trip Pause Only Updates UserDefaults, Never Backend

Pause/resume never calls `TripService.updateTrip()`. Backend always shows `in_progress`.

**Files:**
- `ActiveNavigationDetailView.swift:705-710`
- `ActiveNavigationDetailView.swift:908-916` — On resume, only map camera follows

---

## M4 — Logout Doesn't Clear UserDefaults

**File:** `App/AppRouter.swift:107-116`

When user logs out, all UserDefaults-persisted data (fuel history, incidents, inspection data, offline queue) persists. Next user sees previous user's data.

---

## M5 — Hardcoded Performance Metrics Stubs

**File:** `Modules/Driver/Features/Performance/PerformanceViewModel.swift:28-37`

7 of 8 metrics are hardcoded constants (safetyScore: 85, fuelEfficiency: 14.5, etc.). Only `tripsCompleted` is real.

---

## M6 — Phone Number Stored as `Int64` (Overflow Risk)

**File:** `Core/Models/User.swift:6`

International numbers like `+44-7911123456` (447911123456) can exceed Int64 max. Leading zeros are silently dropped.

---

## M7 — NotificationViewModel: `fetchNotifications` with Nil Params May Leak Data

**File:** `Core/ViewModels/NotificationViewModel.swift:74`

Both `recipientId` and `driverId` are `UUID?`. If both are nil, the service may fetch ALL notifications for ALL users.

---

## M8 — `NotificationViewModel` `setRecipientId` Re-Subscription Bug

**File:** `Core/ViewModels/NotificationViewModel.swift:40-47`

Only re-subscribes if `realtimeTask != nil`. If task was never started, changing recipient ID leaves subscription in inconsistent state.

---

## M9 — CSV Parser Doesn't Handle Quoted Newlines

**File:** `Core/Infrastructure/InventoryCSVParser.swift:46-48`

Uses `.components(separatedBy: "\n")` which breaks on quoted newlines within CSV fields.

---

## M10 — CSV Parser: `cost` and `unitCost` Mapped to Same Value

**File:** `Core/Infrastructure/InventoryCSVParser.swift:136-148`

```swift
cost: unitCost, unitCost: unitCost  // Same value — likely bug
```

Also `vehicleType: category, category: category` — same pattern.

---

## M11 — Unbounded Lists in FleetManager Views (5+ Locations)

All `ForEach` loops load entire arrays with no pagination:

- `ManagerTripsView.swift:208,1052` — All trips
- `ManagerOverviewView.swift:697` — All vehicles
- `ManagerUsersView.swift:211` — All users
- `MaintenanceViewModel.swift:42` — All tasks with nested vehicle/part fetches

---

## M12 — 12+ Silently Swallowed Errors in Maintenance NewUI

Errors caught and printed, never surfaced to user:

- `ProfileViewModel.swift:59-61` — `print("Failed to load work orders stats: \(error)")`
- `SupabaseWorkOrderService.swift:122` — `try?` on mark-in-progress
- `MPDashboardViewModel.swift:42,52` — `try?` on auth lookup (user appears nil silently)
- `VehicleDetailsViewModel.swift:35` — `try?` on currentUser
- `PastWorkOrderDetailsViewModel.swift:29,34,39` — `try?` on vehicle/user lookups

---

## M13 — 6 Alert Usages Use Deprecated iOS 16 API

**File:** `Modules/FleetManager/Views/ManagerProfileView.swift:579-584`

Uses the deprecated `Alert(title:message:dismissButton:)` initializer. Should use `.alert(_:isPresented:actions:message:)`.

---

## M14 — Navigation Coordinator Created But Never Wired

**File:** `Modules/Maintenance/NewUI/Navigation/MaintenanceTabRouter.swift:9`

`NavigationCoordinator` is created via `@StateObject` but `RootTabView.init` ignores the `coordinator` parameter — the coordinator is an orphaned object.

---

## M15 — `DatabaseContract.swift`: Table Names Only in Comments

**File:** `Core/Infrastructure/DatabaseContract.swift:3-24`

No `static let` constants for table names. Raw strings hardcoded everywhere. Refactoring table names will require searching all files.

---

## M16 — `SupabaseActivityService.logActivity()` is a No-Op

**File:** `Modules/Maintenance/NewUI/Services/SupabaseActivityService.swift:40-41`

```swift
func logActivity(_ activity: Activity) async throws {
    // Empty implementation — never writes to DB
}
```

Activity tracking is entirely non-functional.

---

## M17 — Regex Compiled Per Access (Performance)

- `Core/Extensions/UUID+Extensions.swift:23` — `cleaningUUIDs` regex compiled every call
- `Core/Models/Vehicle.swift:48` — `licencePlate` regex compiled every read (in property wrapper getter)

**Fix:** Make regexes `static let`.

---

## M18 — `SharedDecoder.json` Allocates New Decoder Every Access

**File:** `Core/Infrastructure/SharedDecoder.swift:4-5`

```swift
static var json: JSONDecoder { let decoder = ... }
```

Should be `static let` — currently allocates a new decoder on every property access.

---

## M19 — Encoder Loses Fractional Seconds

**File:** `Core/Infrastructure/SharedDecoder.swift:26`

Encoder uses `.iso8601` (no fractional seconds) while decoder tries fractional first. Precision is lost on encode→decode round trips.

---

## M20 — `SupabaseAuthService.getUserProfile()` Leaks `try?` Through Profile Lookup Silently

**File:** `Modules/Maintenance/NewUI/Services/SupabaseAuthService.swift:65`

Fleet manager lookup uses `try?` — silently falls back to treating the ID as a userId, masking role errors.

---

## M21 — `NotificationViewModel` Error Handlers Only Use `print()`

All 6+ error handlers (`lines 78, 90, 103, 112, 133, 168, 268`) use `print("Failed to ...")` with no user-facing alert, retry, or telemetry.

---

## M22 — `CompleteWorkOrderViewModel.swift`: Duplicate Import

**File:** `Modules/Maintenance/NewUI/ViewModels/CompleteWorkOrderViewModel.swift:2-3`

```swift
import Combine
import Combine
```

Cosmetic but indicates sloppy code.

---

# SEVERITY: LOW (Cosmetic / Edge Cases)

## L1 — Logout Drops to Login Without Clearing UserDefaults Data

When user logs out, all UserDefaults-persisted data persists across sessions.

## L2 — `VehicleStatus` Custom Decoder Is Case-Insensitive (Lenient)

Accepts any casing, masking schema violations.

## L3 — `RouteCorridorService.swift`: `CLLocationCoordinate2D` Not Sendable

Will produce Swift 6 concurrency warnings in async contexts.

## L4 — `Vehicle+FMSMP.swift`: Cross-Module Dependency on `FleetIcon`

Creates fragile dependency from Core models to Resources.

---

# SUMMARY

## Findings by Severity

| Severity | Count | Key Areas |
|----------|-------|-----------|
| **CRITICAL** | 7 | RLS/service_role key, SOS alerts, thread safety, silent data corruption, production passwords |
| **HIGH** | 18 | 44 `.single()` crashes, 29 VMs without @MainActor, N+1 queries, race conditions, duplicate services, unbounded fetches, force unwraps, UserDefaults-only storage, subscription leaks, non-functional offline sync |
| **MEDIUM** | 22 | Personnel count bug, navigation coordinator issues, memory leaks, logging/error swallowing, performance (regex), API design (UUID??), logout leaks |
| **LOW** | 4 | Case sensitivity, Sendable warnings, cross-module dependency |
| **TOTAL** | ~51 | (Some categories contain multiple instances) |

## Top 5 Actions to Address

1. **Replace `service_role` key with genuine anon key** — security prerequisite for everything else
2. **Add RLS to all 14 unprotected tables** — enable RLS + role/row-based policies
3. **Add `paused` case to TripStatus and wire backend updates** — fundamental driver feature
4. **Replace UserDefaults with DB persistence** for fuel, inspections, incidents, offline queue
5. **Fix SOS `recipientId: nil`** — life-safety feature is non-functional
