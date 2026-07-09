# File Index

## App Layer

### `FMS/FMS/App/FMSApp.swift`
- **Purpose**: Application entry point (`@main`)
- **Responsibilities**: AppDelegate setup, notification permission request, UNUserNotificationCenter delegate
- **Key**: Sets up `AppRouter()` in `WindowGroup`
- **Note**: SwiftUI lifecycle with `@UIApplicationDelegateAdaptor`

### `FMS/FMS/App/AppRouter.swift`
- **Purpose**: Root navigation router and dependency injection container
- **Responsibilities**: Creates `AppServices` (all service instances), routes users by role, handles splash → login → role routing
- **Key types**: `AppServices`, `AppScreen`
- **Key methods**: `route(for:)`, `logout()`
- **Note**: `AppServices` is `@MainActor final class` — all services initialized here

### `FMS/FMS/Core/Infrastructure/SupabaseService.swift`
- **Purpose**: Wraps `SupabaseClient`
- **Key**: `final actor` with `nonisolated let client`
- **Note**: All services depend on `SupabaseServiceProtocol`, not the concrete type

### `FMS/FMS/Core/Infrastructure/EnvironmentConfig.swift`
- **Purpose**: Reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `Info.plist`
- **Key**: Fatal error if missing — app crashes at startup without config

### `FMS/FMS/Core/Infrastructure/SharedDecoder.swift`
- **Purpose**: Shared JSON encoder/decoder with ISO8601 date handling
- **Key**: Handles both `iso8601` and `iso8601Fractional` date formats

### `FMS/FMS/Core/Infrastructure/DatabaseContract.swift`
- **Purpose**: Documentation-only — table-to-model mapping, naming conventions, DTO strategy
- **Key**: Documents the "no DTO layer" design decision

### `FMS/FMS/Core/Infrastructure/InventoryCSVParser.swift`
- **Purpose**: CSV parsing for inventory import, template generation, low-stock quotation
- **Key**: Validates headers, rows, duplicate SKUs; returns CSVImportResult with errors and valid rows

---

## Core — Enums (5 files)

| File | Path | Cases |
|------|------|-------|
| `VehicleStatus.swift` | `Core/Enums/VehicleStatus.swift` | `available`, `assigned`, `inMaintenance`, `outOfService` |
| `TripStatus.swift` | `Core/Enums/TripStatus.swift` | `scheduled`, `pending`, `accepted`, `rejectionPending`, `rejected`, `inProgress`, `completed`, `cancelled` |
| `MaintenanceTaskStatus.swift` | `Core/Enums/MaintenanceTaskStatus.swift` | `scheduled`, `assigned`, `inProgress`, `onHold`, `completed`, `fake` |
| `UserRole.swift` | `Core/Enums/UserRole.swift` | `fleetManager`, `driver`, `maintenancePersonnel` |
| `PersonnelStatus.swift` | `Core/Enums/PersonnelStatus.swift` | `active`, `inactive` |

---

## Core — Models (20+ files)

**Important models (read before editing):**

| File | Key Fields | CodingKeys |
|------|-----------|------------|
| `User.swift` | `id`, `aadhar`, `role`, `isActive`, `deletedAt` | `userid`, `aadhar`, `isactive`, `deleted_at` |
| `Vehicle.swift` | `id`→`vin`, `status`, `vehicleType`, `fuelType`, `deletedAt` | `vin`, `licence_plate`, `vehicletype`, `fuel_type` |
| `Trip.swift` | `id`, `vehicleId?`, `driverId?`, `vehicleTypeRequested?` | `tripid`, `vehicleid`, `driverid`, `vehicletype_requested` |
| `Driver.swift` | `id`, `licenceNum`, `vehicleType`, `status`, `userId` | `driverid`, `licencenum`, `vehicletype`, `userid` |
| `DriverScore.swift` | `id`, `driverId`, `overallScore`, 4 factor fields | `driver_id`, `overall_score`, `inspection_false_rate`, etc. |
| `DriverSchedule.swift` | `id`, `driverId`, `startTime`, `endTime`, `isAvailable` | `driver_id`, `start_time`, `end_time`, `is_available` |
| `VehicleDocument.swift` | `id`, `vehicleId`, `docType`, `docNumber`, `deletedAt` | `vehicle_id`, `doc_type`, `doc_number`, `deleted_at` |
| `VehicleInspection.swift` | `id`, `tripId`, `vehicleId`, `type`, `status` | `trip_id`, `vehicle_id`, `driver_id` |
| `ExpenseEntry.swift` | `id`, `tripId?`, `vehicleId`, `expenseType`, `fuelType?` | `trip_id`, `vehicle_id`, `expense_type`, `fuel_type` |
| `AppNotification.swift` | `id`, `title`, `message`, `type`, `recipientId?` | `is_read`, `reference_id`, `recipient_id`, `created_at` |
| `MaintenanceTask.swift` | `id`, `status`, `onHoldReason?`, `onHoldAt?` | status check includes `on_hold` |

---

## Services Layer

### `FMS/FMS/Services/AuthService.swift`
- **Dependencies**: `SupabaseServiceProtocol`
- **Key methods**: `signUp`, `signIn`, `signOut`, `currentSession`, `inviteUser`, `sendRecoveryOTP`, `verifyOTP`, `updateUserPassword`, `forceUpdatePassword`, `deleteUserAuth`
- **Note**: Calls 3 edge functions (`invite-user`, `force-update-password`, `delete-user`) that have no source in repo

### `FMS/FMS/Services/VehicleService.swift`
- **Dependencies**: `SupabaseServiceProtocol`
- **Key methods**: `fetchVehicles` (filters deleted_at=nil), `createVehicle`, `updateVehicle`, `deleteVehicle` (soft), `setVehicleStatus`, `fetchVehicleDocuments`, `fetchVehicleHealthScores`
- **Note**: VehicleHealthScores queries 5 tables for 5-factor computation

### `FMS/FMS/Services/TripService.swift`
- **Dependencies**: `SupabaseServiceProtocol`
- **Key methods**: `fetchTrips`, `createTrip`, `updateTrip`, `subscribeToTrips` (realtime), `logTelemetry`, `createDeviationAlert`, `persistRouteWaypoints`
- **Note**: `subscribeToTrips` uses `AsyncStream<Void>` — yields when trip changes affect the driver

### `FMS/FMS/Services/UserManagementService.swift`
- **Dependencies**: `SupabaseServiceProtocol`
- **Key methods**: `fetchUsers` (filters deleted_at=nil), `deleteUser` (soft), `calculateAndUpsertDriverScore` (4-factor), `fetchDriverScores`, `upsertDriverScore`
- **Note**: `deleteDriverByUserId` / `deleteMaintenancePersonnelByUserId` / `deleteFleetManagerByUserId` are no-ops (preserve role rows)

### `FMS/FMS/Services/NotificationService.swift`
- **Dependencies**: `SupabaseServiceProtocol`
- **Key methods**: `fetchNotifications`, `createNotification`, `markAsRead`, `deleteNotification`, `clearAllNotifications`, `subscribeToRealtime`, `subscribeToTripsRealtime`
- **Note**: Uses Realtime channels for live notification delivery

### `FMS/FMS/Services/InspectionService.swift`
- **Dependencies**: `SupabaseServiceProtocol`
- **Key methods**: CRUD on `vehicle_inspections` and `inspection_items` tables

### `FMS/FMS/Services/ExpenseService.swift`
- **Dependencies**: `SupabaseServiceProtocol`
- **Key methods**: CRUD on `expense_entries` table

### `FMS/FMS/Services/WorkOrderAssignmentService.swift`
- **Dependencies**: `UserManagementServiceProtocol`, `MaintenanceServiceProtocol`
- **Key methods**: `findBestPersonnel()` — finds least-loaded active maintenance personnel

### `FMS/FMS/Services/MaintenanceService.swift`
- **Dependencies**: `SupabaseServiceProtocol`
- **Key methods**: CRUD on `maintenance_task`, `task_vehicles`, `maintenance_task_parts`; `holdTask`, `unholdTask`

### `FMS/FMS/Services/OCRService.swift`
- **Purpose**: Image-based OCR for fuel gauge reading and receipt extraction
- **Key methods**: `extractFuelLevel(from:completion:)`, `extractReceiptInfo(from:completion:)`

---

## Fleet Manager Views

| File | Purpose |
|------|---------|
| `FleetManagerDashboardView.swift` | Root FM view: TabView + sheet router + notification wiring |
| `ManagerOverviewView.swift` | Live tab with operational overview cards |
| `ManagerVehiclesView.swift` | Vehicle list with filters, health scores, compliance docs |
| `ManagerVehicleFormSheet.swift` | Add/edit vehicle form (fuel type, maintenance intervals) |
| `VehicleComplianceDocsView.swift` | Document list per vehicle with add/delete |
| `ManagerUsersView.swift` | User list segmented by role |
| `ManagerUserFormSheet.swift` | Add/edit user form |
| `ManagerTripsView.swift` | Trip list with status filters, rejection requests |
| `ManagerTripFormSheet.swift` | Create trip form (no driver/vehicle select, vehicle type picker) |
| `ManagerMaintenanceView.swift` | Work orders, inventory, CSV import |
| `ManagerMaintenanceRequestSheet.swift` | Create work order form |
| `ReportsHubView.swift` | Report category grid → detail views |
| `ReportExportToolbarItem.swift` | ShareLink-based CSV/PDF export in toolbar |

---

## Fleet Manager ViewModels

| File | Purpose |
|------|---------|
| `TripManagementViewModel.swift` | Trip CRUD, auto-assignment algorithm, rejection handling |
| `VehicleViewModel.swift` | Vehicle CRUD, document management, health scores |
| `UserManagementViewModel.swift` | User CRUD, driver scores, role management |
| `MaintenanceViewModel.swift` | Work order CRUD, auto-assignment integration |
| `ReportsViewModel.swift` | All report calculations, period filtering |
| `ReportExporter.swift` | CSV and PDF generation for 6 report types |
| `ManagerNotificationController.swift` | FM-specific notification handling |

---

## Driver Views

| File | Purpose |
|------|---------|
| `DriverDashboardView.swift` | Root driver: loads data, wires realtime, creates LocationManager |
| `DashboardView.swift` | Main driver dashboard: trips, accept/reject, navigation |
| `ActiveNavigationDetailView.swift` | Real GPS navigation map, route polyline, deviation |
| `ActiveTrackingView.swift` | Alternative tracking view |
| `EndTripView.swift` | Post-trip inspection with checklist, odometer, fuel |
| `TripDetailView.swift` | Trip details with accept/reject actions |
| `InspectionView.swift` | Pre-trip inspection with photo requirement |
| `FuelRequestView.swift` | Fuel entry with CNG/kg support, OCR receipt |
| `FuelHistoryView.swift` | Past fuel entries list |
| `LocationManager.swift` | Core location: tracking, adaptive frequency, buffering, geofence |

---

## Maintenance NewUI — Notable Files

| File | Purpose |
|------|---------|
| `MaintenanceTabRouter.swift` | Entry point: creates AppDependencyContainer |
| `RootTabView.swift` | Tab view with NavigationCoordinator |
| `AppDependencyContainer.swift` | DI container for NewUI module |
| `NavigationCoordinator.swift` | Tab-based navigation state manager |
| `AppRoute.swift` | Navigation destination enum |
| `RouteViewFactory.swift` | Maps AppRoute → View |
| `SupabaseWorkOrderService.swift` | Work order CRUD for NewUI |
| `SupabaseVehicleService.swift` | Vehicle CRUD for NewUI |
| `CompleteWorkOrderViewModel.swift` | Work order completion with status transitions |
| `MPDashboardViewModel.swift` | Dashboard for maintenance personnel |
| `WorkOrderCard.swift` | Reusable work order display card |
| `VehicleCard.swift` | Reusable vehicle display card |
| `Theme/AppColor.swift` | NewUI color system |
| `Theme/AppTypography.swift` | NewUI typography system |

---

## Resources

| File | Purpose |
|------|---------|
| `FleetPalette.swift` | Shared color system |
| `FleetTypography.swift` | Shared typography system |
| `FleetIcon.swift` | Shared icon names |
| `ViewModifiers.swift` | Shared SwiftUI view modifiers |
| `Components/MetricCard.swift` | Reusable metric display card |
| `Components/StatusBadge.swift` | Status badge component |
| `Components/GlassPanel.swift` | Glass-morphism panel |
| `Components/SearchBar.swift` | Reusable search bar |
| `Components/InfoRow.swift` | Key-value info row |
| `Components/ScreenHeader.swift` | Screen header with title |
| `Components/FeedbackView.swift` | Success/error feedback view |

---

## Database Migrations

Located at `FMS/Database/migrations/` (22 files, timestamped `YYYYMMDD_description.sql`):

| Migration | Purpose |
|-----------|---------|
| `20260707_vehicle_status_enum.sql` | New vehicle status CHECK constraint |
| `20260707_soft_delete.sql` | `deleted_at` on users, vehicles |
| `20260707_vehicle_documents.sql` | New vehicle_documents table |
| `20260707_driver_scores.sql` | New driver_scores table |
| `20260707_driver_schedules.sql` | New driver_schedules table |
| `20260707_vehicle_inspections.sql` | New vehicle_inspections + inspection_items tables |
| `20260707_expense_entries.sql` | New expense_entries table (CNG, no EV) |
| `20260707_maintenance_task_on_hold.sql` | on_hold status support |
| `20260707_inventory_schema.sql` | New inventory columns |
| `20260707_telemetry_log_extended.sql` | tripid, vehicleid, heading columns |
| `20260707_trips_vehicleid_nullable.sql` | trips.vehicleid nullable |
| `20260707_vehicle_fuel_type_check.sql` | Fuel type constraint (petrol/diesel/cng) |
| `20260707_vehicle_maintenance_intervals.sql` | Maintenance interval columns |
| `20260707_notification_delete_rls.sql` | DELETE RLS on notifications |
| `20260707_phase1_table_permissions.sql` | Permissions for 6 new tables |

---

## Edge Functions

| Function | Location in Repo | Status |
|----------|-----------------|--------|
| `send-recovery-otp` | `FMS/FMS/EdgeFunctions/send-recovery-otp/index.ts` | Exists |
| `send-password-reset` | `FMS/FMS/EdgeFunctions/send-password-reset/index.ts` | Exists |
| `invite-user` | Not in repo | Referenced by AuthService, assumed deployed |
| `force-update-password` | Not in repo | Referenced by AuthService, assumed deployed |
| `delete-user` | Not in repo | Referenced by AuthService, assumed deployed |
