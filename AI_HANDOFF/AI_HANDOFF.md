# AI Handoff Document — Fleet Management System

## Overview

Fleet Management System (FMS) is an iOS application for managing a commercial fleet of vehicles, drivers, maintenance personnel, and operational workflows. It supports three roles: Fleet Manager, Driver, and Maintenance Personnel. The app is built with SwiftUI, uses Supabase as its backend (database, auth, realtime, storage, edge functions), and targets iOS 18+ (currently building against SDK 26).

## Purpose

Streamline fleet operations including vehicle tracking, trip assignment, driver management, maintenance work orders, fuel/expense tracking, inventory management, compliance document tracking, and operational reporting.

## Repository Location

`/Users/abcom/Documents/Fleet-Management-System/FMS/`

## Current Branch

`fix/Overnight-sprint` — pushed to remote `origin/fix/Overnight-sprint`

## Major Features

| Feature | Status | Description |
|---------|--------|-------------|
| Auth (email/password) | Complete | Sign up, sign in, session management, forgot password OTP |
| Role-based routing | Complete | Fleet Manager, Driver, Maintenance Personnel entry points |
| User management | Complete | CRUD users, invite via edge function, soft delete |
| Vehicle management | Complete | CRUD vehicles, status tags, compliance docs, soft delete |
| Trip management | Complete | Create, update, status lifecycle, auto-assignment |
| Trip auto-assignment | Complete | Vehicle type matching, driver ranking by score/workload/schedule |
| Rejection handling | Complete | Driver reject, FM approve/deny, auto-reassignment |
| Driver accept/reject | Complete | Scheduled trip cards with inline accept/reject |
| Active trip tracking | Complete | Real GPS, adaptive frequency, heading, background, offline buffer |
| Geofence/route corridor | Complete | Waypoint generation, deviation detection, alerts |
| Pre/post trip inspections | Complete | DB-persisted checklist, required photos on failure, work order creation |
| Fuel/expense tracking | Complete | Supabase-backed, CNG support, OCR receipt parsing |
| Inventory management | Complete | CSV import, low-stock quotation, threshold monitoring |
| Reports & export | Complete | 6 report types, CSV + PDF export, 2M/4M/8M/1Y periods |
| Driver scoring | Complete | 4-factor formula from inspections, geofence, compliance, mileage |
| Vehicle health scoring | Complete | 5-factor formula from age, fuel, maintenance, inspections, burden |
| Notification system | Complete | DB-persisted, realtime push, clear/delete, targeted recipients |
| Maintenance work orders | Complete | CRUD, on_hold status, auto-assignment to personnel |
| Work order auto-assignment | Complete | By lowest workload, active personnel, eligible users |
| Soft delete | Complete | Users and vehicles archived, history preserved |

## What Has Been Completed

All major feature areas from the original phased plan. The following are fully implemented:

- Phase 1 (Structural): SQL migrations, enums, models, soft delete, service protocols
- Phase 2A: Vehicle add/edit/compliance docs UI
- Phase 2B: Trip creation — removed driver/vehicle picker, added vehicle type request
- Phase 2C: Trip auto-assignment algorithm (score × 0.5 + workload × 0.3 + schedule × 0.2)
- Phase 2D: Rejection approval auto-reassignment
- Phase 2E: Pre/post inspection persistence with required photos on failure
- Phase 2F: Active trip tracking with real GPS, adaptive frequency, background, buffering
- Phase 2G: Fuel/expenses moved to Supabase, CNG support, OCR receipt parsing
- Phase 2H: Inventory CSV import with validation, template download, low-stock quotation
- Phase 2I: Notification clear/delete, event notifications for all major actions
- Phase 2I.1: Tightened notification recipients (targeted, not broadcast)
- Phase 2J: Driver scoring (4 factors) and vehicle health scoring (5 factors)
- Phase 2K: Reports export (CSV + PDF) for 6 report types
- Phase 2L: Work order auto-assignment to maintenance personnel
- Phase 2M: Geofence breach scoring hook + notification targeting

## What Is Partially Complete

- **Edge Functions**: `send-recovery-otp` and `send-password-reset` exist in repo. `invite-user`, `force-update-password`, and `delete-user` are referenced by `AuthService.swift` but source is not in the repository. They must be assumed to exist on deployed Supabase.
- **Multi-tenancy**: No tenant/company model exists. The app operates as single-tenant. Adding multi-tenant support would require a company/org model, tenant IDs on all tables, and RLS policy rewrites.
- **RLS Policies**: Phase 1 added RLS policies for 6 new tables with `authenticated USING (true)` pattern. Notifications table has insert/select/update/delete policies. Other tables likely have wide-open policies. Full RLS audit is needed.
- **Tests**: Test targets exist but contain only template tests. No meaningful test coverage.
- **Secrets security**: `Secrets.debug.xcconfig` and `Secrets.release.xcconfig` contain Supabase credentials and are committed to the repo. The key stored appears to be a service_role key used as an anon key. This is a security vulnerability.

## What Has Not Been Implemented

- **Full offline support**: Explicitly excluded by SRS. `OfflineSyncManager` exists but is a simulated/local-only queue.
- **Excel (.xlsx) export**: Reports export CSV and PDF only. No true Excel format.
- **Purchase orders**: Excluded from scope by design decision.
- **Geofence severity classification**: Intentionally excluded. Any breach is simply a breach.
- **Driver score impact from geofence**: Implemented as a scoring hook (geofence violation rate feeds the score formula), but not as a separate UI or severity system.
- **Fleet chat**: `FleetManagerChatView.swift` exists but appears to be a placeholder/simulated view.

## Important Architectural Decisions

1. **MVVM with ObservableObject**: The app uses `@MainActor` view models with `@Published` properties and `@StateObject`/`@ObservedObject` wiring. The newer Maintenance `NewUI` module uses the same pattern but with a coordinator/navigation state approach for tab-based navigation.

2. **Actor-based services**: All services are `final actor` classes for thread safety. They take `SupabaseServiceProtocol` (not `SupabaseClient` directly). The protocol is `Sendable`.

3. **No DTO layer**: Models map 1:1 to database tables via `Codable` with `CodingKeys` for snake_case mapping. This means schema changes can break UI/service code directly.

4. **Manual dependency injection**: `AppServices` (defined in `AppRouter.swift`) is a root container that initializes all services. It is passed as a single object to view models and views. The Maintenance NewUI has its own `AppDependencyContainer` class.

5. **Two service ecosystems coexist**: The shared `Services/` folder has one set of protocols and actor implementations. The Maintenance `NewUI` module has its own service protocols (`Servicing` suffix), implementations, and mock services. Some functionality is duplicated (e.g., vehicle fetching exists in both `VehicleService` and `SupabaseVehicleService`).

6. **Notification targeting**: After Phase 2I.1, all notification sends use explicit `recipientId` targeting. Broadcast (`recipientId: nil`) is avoided for role-specific events.

7. **Work order status lifecycle**: `scheduled → assigned → in_progress → on_hold → completed / fake`. Opening the completion screen marks `in_progress` intentionally (starts labor time tracking). No `verified` or `closed` statuses exist.

8. **Trip status lifecycle**: `pending → accepted → in_progress → completed / cancelled`. With intermediate states: `rejection_pending`, `rejected`, `scheduled`.

9. **Vehicle statuses**: `available`, `assigned`, `in_maintenance`, `out_of_service`.

10. **Report periods**: 2M, 4M, 8M, 1Y. Intentional deviation from SRS; SRS should be updated to match.

11. **Driver score formula**: 4 factors (inspection false rate, geofence violation rate, compliance violation rate, mileage accuracy). Not the original SRS 7-factor design.

## Coding Conventions

- **Naming**: `camelCase` in Swift, `snake_case` in database. `CodingKeys` used for all models mapping snake_case DB columns.
- **File naming**: Files named after model/service types. Protocols prefixed with domain name (e.g., `VehicleServiceProtocol`). Implementations named without "Protocol" suffix.
- **Folders**: Grouped by role (Modules/Driver, Modules/FleetManager, Modules/Maintenance) with ViewModels, Views subfolders. Shared code in Core/.
- **Date handling**: ISO 8601 with fractional seconds for timestamptz. `@DateOnly` property wrapper for date-only columns. SharedDecoder handles both formats.
- **UUIDs**: All PKs are UUIDs. Sent as uuidString representation. PostgREST handles UUID type coercion.
- **Services**: Actors with `SupabaseServiceProtocol` dependency. Methods are `async throws`. Most return decoded model types directly.

## Design Patterns

- **MVVM**: View owns ViewModel via `@StateObject`, ViewModel owns service via protocol, service queries Supabase.
- **Actor isolation**: Services are actors, guaranteeing thread safety for Supabase operations.
- **Protocol-oriented**: Every service has a protocol. View models depend on protocols, not concrete types.
- **Dependency injection**: Manual via container objects. `AppServices` for main app, `AppDependencyContainer` for Maintenance NewUI.
- **Coordinator (limited)**: NavigationCoordinator for Maintenance NewUI tabs. Fleet Manager uses inline `@State` for tabs and sheets.
- **Singleton (limited)**: `SupabaseService` is created once in `AppServices`. `LocalDataStore.shared` is a singleton for backward compat.

## State Management

- `@State` for local view state (selectedTab, isShowingSheet, etc.)
- `@StateObject` for view model lifecycle management
- `@ObservedObject` for shared view models passed between parent/child views
- `@Published` within view models for observable properties
- `@EnvironmentObject` for LocationManager in driver flow
- `@MainActor` annotation on all view models

## Dependency Injection

Root container (`AppServices`) in `AppRouter.swift`:
```
AppServices
├── supabase: SupabaseService
├── authService: AuthService
├── vehicleService: VehicleService
├── tripService: TripService
├── maintenanceService: MaintenanceService
├── inventoryService: InventoryService
├── userManagementService: UserManagementService
├── fleetNotificationService: FleetNotificationService
├── notificationService: NotificationService
├── inspectionService: InspectionService
├── expenseService: ExpenseService
└── workOrderAssignmentService: WorkOrderAssignmentService
```

Maintenance NewUI container (`AppDependencyContainer`) in `AppDependencyContainer.swift`:
```
AppDependencyContainer
├── vehicleService: VehicleServicing
├── workOrderService: WorkOrderServicing
├── activityService: ActivityServicing
├── authService: AuthServicing
├── notificationService: NotificationServicing
├── apiClient: APIClient
├── sessionManager: SessionManager
└── featureFlagManager: FeatureFlagManager
```

## Navigation Architecture

- **Root**: `FMSApp` → `AppRouter` (switch on AppScreen enum: splash/login/firstTimeSetup/fleetManager/maintenancePersonnel/driver)
- **Fleet Manager**: `TabView` with 5 tabs (Live/Users/Vehicles/Trips/Workshop). Each tab has its own `NavigationStack`. Sheets for adding/editing entities. NavigationDestinations for notifications and reports.
- **Driver**: `DriverDashboardView` → `DashboardView` (features inline). Sheet-based trip detail and reject. NavigationLink-based trip flow.
- **Maintenance**: `MaintenanceTabRouter` → `RootTabView` → `NavigationCoordinator` manages tab state (Dashboard/My Jobs/Inventory/More). Uses `AppRoute` enum and `RouteViewFactory` for programmatic navigation.

## Error Handling Strategy

- Services throw errors from Supabase SDK or custom `AuthError` enum.
- View models catch errors and set `@Published errorMessage` strings.
- Views display errors via `Alert` or inline text.
- CancellationError is silently ignored in view models (task cancellation is expected).
- Validation is done in view models and form models before service calls.
- AuthService functions have specific error messages for common failure modes.

## Networking Strategy

- All networking goes through `SupabaseClient` (provided by supabase-swift SDK).
- Maintenance NewUI also uses `APIClient` (a custom REST wrapper).
- Edge Functions called via `URLSession.shared` with bearer token from current session.
- No direct REST endpoint calls outside Supabase and edge functions.

## Realtime Strategy

- Supabase Realtime channels for:
  - `notifications` table (INSERT) — all users receive new notifications
  - `trips` table (INSERT/UPDATE) — drivers receive trip changes
- Channels named with UUID patterns for uniqueness: `notifications-realtime-{UUID}`, `trips-realtime-{UUID}`
- `AsyncStream<Void>` and `AsyncStream<AppNotification>` used for event streams
- `subscribeToTripsRealtime()` posts `NotificationCenter` "ReloadTrips" for driver dashboard refresh
- 20-second polling timer as fallback in Fleet Manager dashboard

## Authentication Strategy

- Supabase Auth (email/password)
- Sign up creates auth user + `users` row + `fleet_manager` role row
- Invite user via `invite-user` edge function → creates auth identity
- Forgot password flow via `send-recovery-otp` edge function → OTP → password reset
- Session persisted by Supabase SDK
- `currentSession()` fetches user profile from `users` table by auth user ID
- First-time login flag on user record triggers `FirstTimeSetupView` profile completion

## Data Flow

```
Info.plist → EnvironmentConfig → SupabaseService → SupabaseClient
  ↓
Service Actor → Supabase query via client.from("table").select()
  ↓
SharedDecoder (ISO8601 + fractional seconds)
  ↓
Decoded Model (Codable struct with CodingKeys)
  ↓
ViewModel (@MainActor, @Published properties)
  ↓
SwiftUI View (@StateObject / @ObservedObject)
```

## Current Assumptions

1. **Single-tenant**: No tenant isolation. All users see all data.
2. **PKs are UUIDs**: All primary keys and foreign keys use UUID type.
3. **`vehicles.vin` is UUID**: The DB stores VIN as UUID in the `vin` column. The Swift model maps `id` to `vin`.
4. **Edge functions exist on Supabase**: `invite-user`, `force-update-password`, `delete-user` are called but their source is not in the repo.
5. **Notification column name**: `recipient_id` (confirmed via schema check; some old SQL seeds used `recipient_userid` but the actual table uses `recipient_id`).
6. **`auth.uid()` returns UUID**: RLS policies assume `auth.uid()` returns UUID-compatible value.
7. **Supabase anon key in xcconfig**: Currently set to what appears to be a service_role key. Needs rotation.
8. **Driver license validation**: Indian DL format patterns are used.

## Known Limitations

- **No DTO layer**: Schema changes directly affect Swift models and services.
- **No tenant isolation**: Multi-tenancy would require significant schema and query changes.
- **Secrets committed**: xcconfig files with credentials are in the repo.
- **Two service ecosystems**: Shared Services/ and Maintenance NewUI services overlap.
- **Tests missing**: Only template test files exist.
- **Edge function source missing**: 3 of 5 edge functions have no source in repo.
- **RLS policies incomplete**: New tables have wide-open `authenticated USING (true)` policies.
- **LocalDataStore still used**: Backward-compat writes to both UserDefaults and Supabase for fuel records.
- **`NavigationView` in Driver tab**: `MainTabView.swift` uses deprecated `NavigationView` instead of `NavigationStack`.
- **Duplicate migration locations**: Migrations exist at `FMS/Database/migrations/` and one at `FMS/FMS/Database/migrations/`.

## Important Implementation Notes

- **Work order opening**: `CompleteWorkOrderViewModel` sets status to `in_progress` on `onAppear` of the completion screen. This is by design — labor time starts when personnel opens the work order.
- **`isPlaceholderDemoRecord` in VehicleViewModel**: Filters out hard-coded demo records ("UK071234", etc.). These can be removed when demo data is cleaned up.
- **`calculatedAt` encoding note**: `DriverScore.calculatedAt` uses `= .string(ISO8601DateFormatter().string(from: Date()))` rather than the shared encoder. This is intentional for consistent timestamp format in upsert queries.
- **ReportsViewModel wiring**: Has references to all other view models. Changes to vehicle/trip/driver/maintenance view models can break reports.
- **`WorkOrderAssignmentService` depends on `UserManagementService` and `MaintenanceService`**: This creates a potential dependency cycle risk if services are restructured.
- **`ThresholdStore.shared`**: Configured in `AppServices.init()` with Supabase client. Used by Maintenance NewUI for local threshold caching.
- **Notification dedup**: Uses `notifiedTripKeys` (Set<String>) in NotificationViewModel and `lastTripNotificationMessage`/`lastMaintenanceNotificationMessage` in FleetManagerDashboardView to prevent duplicate notifications. Also has realtime dedup guard.

## Hidden Dependencies

- **VehicleViewModel → VehicleService.doc methods → vehicle_documents table**: Document CRUD depends on Phase 1 migration.
- **TripManagementViewModel → UserManagementService.fetchDrivers/fetchUsers/fetchDriverScore**: Auto-assignment depends on user management data.
- **ReportsViewModel → all other view models**: Reports cannot work if any FM view model is broken.
- **EndTripView → LocationManager.stopTracking()**: Trip completion stops GPS tracking.
- **InspectionView/EndTripView → WorkOrderAssignmentService**: Creating work orders depends on maintenance auto-assignment.
- **MaintenanceTabRouter → AppDependencyContainer.supabase()**: Initializes its own services. Changes to SupabaseVehicleService or SupabaseWorkOrderService in the NewUI module do not affect shared services.
- **NotificationViewModel.addLocalNotification() → NotificationService.createNotification()**: Local notifications are also persisted to Supabase.
- **calculateAndUpsertDriverScore**: Called from `TripManagementViewModel.updateStatus(.completed)` and `LocationManager.triggerDeviationAlert`. Changes to scoring logic affect trip completion performance.

## Anything Another AI Must Know Before Writing Code

1. **Edit the correct service layer**: Use `Services/` protocols and actors for Fleet Manager and Driver features. Use `Modules/Maintenance/NewUI/Services/` for Maintenance Personnel features. Some files exist in both (e.g., vehicle, work order, notification services).

2. **Protocols and implementations must stay in sync**: If you change a protocol, the implementation must be updated simultaneously or the build will break.

3. **Mock/Preview services**: The Maintenance NewUI has mock services in `Services/Mocks/`. Three `PreviewNotificationService` mocks also exist in `AppRootView`, `RootTabView`, and `MPDashboardView`. Protocol changes must be reflected in all mocks.

4. **Migration files should be timestamped**: Name pattern `YYYYMMDD_description.sql`. Add to `FMS/Database/migrations/`. Do not use the duplicate `FMS/FMS/Database/migrations/` path.

5. **Build command**: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FMS/FMS.xcodeproj -scheme FMS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build`

6. **Vehicle ID type**: `id` maps to `vin` in DB. All FK references use UUID type matching the vin column.

7. **Trip.vehicleId is optional**: Trip creation can leave vehicleId as nil. Any code processing trips must use `compactMap` on vehicleId for reporting to avoid counting nil as a vehicle.

8. **Secrets are in the repo**: Do not add new secrets. Do not commit the current secrets to new branches. Minimal change: replace the xcconfig keys with true anon keys and add to .gitignore.

9. **IF an enum or model case is renamed, search the entire codebase**: Swift enums have CaseIterable, rawValue, and CodingKeys. Old values may be referenced in preview data, colors, filters, and conditional logic.

10. **Notification types are string-based**: `type` field in `AppNotification` and the Supabase `notifications.type` column uses string values. Notification filtering logic in `NotificationViewModel.shouldIncludeNotification` and `FleetManagerDashboardView` onChange handlers relies on string matching. Changing notification types requires updating these filter functions.
