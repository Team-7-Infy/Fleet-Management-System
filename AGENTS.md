# Fleet Management System — Agent Knowledge Base

## Project Overview

| Property | Value |
|----------|-------|
| **Platform** | iOS 18+ (iPhone + iPad) |
| **Architecture** | SwiftUI + MVVM + Actor-based services |
| **Backend** | Supabase (PostgreSQL 15+, Auth, Realtime, Storage) |
| **Auth** | Email + password + OTP; forgot-password OTP via Edge Function |
| **DI** | Manual — `AppServices` root container, protocol-based injection |
| **DB Client** | supabase-swift SDK v2.x |
| **Target SDK** | iOS 18+ (uses async/await, actors, Swift 6) |

---

## Directory Structure (Key Areas)

```
FMS/FMS/
├── App/                         # Entry point, AppRouter, DI container
├── Core/
│   ├── Enums/                   # 5 enums: TripStatus, VehicleStatus, etc.
│   ├── Extensions/              # Color, Date, UUID extensions
│   ├── Infrastructure/          # SupabaseService, SharedDecoder, DateOnly, EnvironmentConfig, DatabaseContract
│   ├── Models/                  # 16 models: User, Driver, Vehicle, Trip, etc.
│   ├── ViewModels/              # NotificationViewModel only
│   └── Views/                   # Notification views only
├── Services/                    # 9 actor services (Auth, Vehicle, Trip, Maintenance, Inventory, UserManagement, Notification, FleetNotification, OCR)
│   └── Protocols/               # 8 protocol interfaces for all services above
├── Modules/
│   ├── Auth/                    # Login, ForgotPassword, FirstTimeSetup, etc.
│   ├── Driver/                  # Dashboard, Trips, Fuel, Incident, SOS, Vehicle/Inspection, Profile, Performance
│   ├── FleetManager/            # Dashboard, Users, Vehicles, Trips, Maintenance, Reports
│   └── Maintenance/NewUI/       # Independent UI system: dashboard, work-orders, inventory, navigation coordinator
├── EdgeFunctions/
│   └── send-recovery-otp/       # OTP email via SMTP
└── Resources/                   # Palette, Typography, Icons, spare_parts.csv, Components/
```

## Database Schema (15 tables)

```
users              (PK: userid)              → Driver, FleetManager, MaintenancePersonnel, Notifications
drivers            (PK: driverid, FK: userid) → Trips, Vehicles, Telemetry_log
fleet_manager      (PK: managerid, FK: userid) → MaintenanceTask.scheduledby
maintenance_personnel (PK: personnelid, FK: userid) → MaintenanceTask.executedby
vehicles           (PK: vin)                 → Trips, DeviationAlert, TaskVehicles
trips              (PK: tripid)              → Geofence, DeviationAlert, RouteWaypoints
geofence           (PK: geofenceid)          → DeviationAlert
deviation_alert    (PK: deviationid)
route_waypoints    (PK: waypointid)
telemetry_log      (PK: telemetryid)
maintenance_task   (PK: taskid)              → MaintenanceTaskParts, TaskVehicles
maintenance_task_parts (PK: id)
task_vehicles      (PK: taskid + vin)
inventory          (PK: partid)
notifications      (PK: id) — RLS enabled
```

## Known Gaps (Pre-Plan)

- **RLS**: Enabled on all 15 tables, but policies are wide-open `"All authenticated can X"` with `qual: true` on every table except `users` (which has FM-scoped update/delete + self-service) and `notifications` (which has self-scoped). The anon key in xcconfig is actually a `service_role` key. **This is critical for all features** — new tables and operations must include proper RLS policies.
- **Duplicate service layers**: Maintenance NewUI has its own services + protocols parallel to `Services/`
- **Fuel entries**: No dedicated `fuel_entries` table — `FuelRecord` struct exists but is local-only (UserDefaults)
- **Vehicle compliance docs**: No tables exist
- **Vehicle inspections**: No dedicated `vehicle_inspections` table — inspections only exist as LocalDataStore + UserDefaults
- **Driver scoring**: Placeholder only (`ReportsViewModel.averageDriverScore` always returns 75)
- **Vehicle health scoring**: Computed in-memory in `ReportsViewModel` from basic heuristics
- **Work order `on_hold` status**: Missing from `MaintenanceTaskStatus`
- **Soft delete**: Hard deletes everywhere — `deleteUser()` actually `DELETE FROM users` 
- **Trip auto-assignment**: `TripManagementViewModel.createTrip` creates trip but no algorithm — driver must be manually selected
- **Driver schedules**: No concept exists
- **Reports export**: `ReportsHubView` renders UI but no PDF/CSV/Excel export
- **Notification clearing**: Mark-as-read exists but no delete/clear functionality
- **Inventory CSV import**: `InventoryCSVLoader` reads from bundled file only — no file-picker CSV import, no template

---

# Implementation Plan — 13 Feature Areas

## 1. Vehicle Status Tags

### Current State
`VehicleStatus` enum: `active`, `inactive`, `maintenance` (3 values).
DB column `vehicles.status` uses these 3 values. SRS VEH-08 requires: `available`, `assigned`, `in_maintenance`, `out_of_service`.

### SRS Requirements (VEH-08, VEH-09)
- Statuses: `available`, `assigned`, `in_maintenance`, `out_of_service`
- FM can manually set to `out_of_service`

### SQL Migration Plan
```sql
-- Add check constraint for new status values
ALTER TABLE vehicles DROP CONSTRAINT IF EXISTS vehicles_status_check;
ALTER TABLE vehicles ADD CONSTRAINT vehicles_status_check 
  CHECK (status IN ('available', 'assigned', 'in_maintenance', 'out_of_service'));
-- Migrate existing
UPDATE vehicles SET status = 'available' WHERE status = 'active';
UPDATE vehicles SET status = 'in_maintenance' WHERE status = 'maintenance';
```

### Affected Files
| Layer | Files |
|-------|-------|
| **Swift Enum** | `Core/Enums/VehicleStatus.swift` — update cases |
| **Swift Model** | (none — model uses String-backed enum) |
| **Service** | `Services/VehicleService.swift` — add `setOutOfService()` |
| **ViewModel** | `Modules/FleetManager/ViewModels/VehicleViewModel.swift` — add toggle action |
| **View** | `Modules/FleetManager/Views/Vehicles/VehicleActionMenu.swift`, `ManagerVehicleFormSheet.swift` |
| **DB** | Migration script |

---

## 2. Vehicle Compliance Documents

### Current State
No compliance/doc table exists. SRS COM-01–COM-04 requires insurance, registration, road tax, permit, PUC documents per vehicle.

### SQL Migration Plan
```sql
CREATE TABLE vehicle_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(vin) ON DELETE CASCADE,
  doc_type TEXT NOT NULL CHECK (doc_type IN ('insurance', 'registration', 'road_tax', 'permit', 'puc')),
  doc_number TEXT NOT NULL,
  issue_date DATE NOT NULL,
  expiry_date DATE NOT NULL,
  file_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_vehicle_docs_vehicle ON vehicle_documents(vehicle_id);
CREATE INDEX idx_vehicle_docs_expiry ON vehicle_documents(expiry_date);
```

### Affected Files
| Layer | Files |
|-------|-------|
| **Swift Model** | New `Core/Models/VehicleDocument.swift` |
| **Service Protocol** | `Services/Protocols/VehicleServiceProtocol.swift` — add doc CRUD |
| **Service** | `Services/VehicleService.swift` — implement doc methods |
| **ViewModel** | `Modules/FleetManager/ViewModels/VehicleViewModel.swift` — add doc state |
| **View** | New `Modules/FleetManager/Views/Vehicles/VehicleDocsView.swift` |
| **DB** | Migration script |

---

## 3. Soft Delete for Users & Vehicles

### Current State
`UserManagementService.deleteUser()` does `DELETE FROM users`. `VehicleService.deleteVehicle()` does `DELETE FROM vehicles`. SRS requires soft-delete (UM-04, VEH-03).

### SQL Migration Plan
```sql
-- Users: add deleted_at
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;
-- Vehicles: add deleted_at  
ALTER TABLE vehicles ADD COLUMN deleted_at TIMESTAMPTZ;
-- Update all queries in services to filter WHERE deleted_at IS NULL
```

### Affected Files
| Layer | Files |
|-------|-------|
| **Swift Model** | `User.swift`, `Vehicle.swift` — add `deletedAt: Date?` |
| **Service** | `UserManagementService.swift` — change `deleteUser` → set `deleted_at`, add filters to all `fetch*` |
| **Service** | `VehicleService.swift` — change `deleteVehicle` → set `deleted_at`, add filters to all `fetch*` |
| **View** | Manager users/vehicles list views — handle archived state display |
| **DB** | Migration script |

---

## 4. Trip Auto-Assignment

### Current State
`FleetManagerTripForm` requires `driverId` to be manually selected. `TripManagementViewModel.createTrip` assigns manually. SRS TRP-02 requires automatic assignment via algorithm.

### SRS Requirements
Algorithm: Hard filter by authorized vehicle type → rank by proximity, availability, schedule fit, driver score.

### SQL/Service Changes
Need an RPC or in-app algorithm. The algorithm operates across `drivers` (vehicletype), `users` (active), `vehicles` (status, assigned), `trips` (availability).

### Affected Files
| Layer | Files |
|-------|-------|
| **Service Protocol** | `Services/Protocols/TripServiceProtocol.swift` — add `findBestDriver(for:)` |
| **Service** | `Services/TripService.swift` — implement algorithm |
| **ViewModel** | `TripManagementViewModel.swift` — call auto-assign after create, wire up override flow |
| **View** | `ManagerTripFormSheet.swift` — show suggested driver, allow override |
| **DB** | New RPC: `find_best_driver_for_trip(p_vehicle_type, p_start_lat, p_start_lng)` |

---

## 5. Driver Schedules

### Current State
No schedule concept exists. SRS doesn't explicitly define schedules but TRP-02 mentions "schedule fit" as an assignment factor.

### SQL Migration Plan
```sql
CREATE TABLE driver_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(driverid) ON DELETE CASCADE,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  is_available BOOLEAN NOT NULL DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_driver_schedules_driver_time ON driver_schedules(driver_id, start_time, end_time);
```

### Affected Files
| Layer | Files |
|-------|-------|
| **Swift Model** | New `Core/Models/DriverSchedule.swift` |
| **Service Protocol** | `Services/Protocols/UserManagementServiceProtocol.swift` — add schedule CRUD |
| **Service** | `UserManagementService.swift` — implement schedule methods |
| **ViewModel** | `Modules/FleetManager/ViewModels/UserManagementViewModel.swift` |
| **View** | New schedule management views |
| **DB** | Migration script |

---

## 6. Driver Score Inputs

### Current State
`ReportsViewModel.averageDriverScore` always returns 75. No driver score table or computation exists.

### SRS Requirements (DSC-01–DSC-04)
Score (0–100) from 7 factors: route adherence (1/7), trip completion (1/7), schedule adherence (1/7), inspection compliance (1/7), defect reporting (1/7), route deviation history (1/7), fuel consumption (1/7). Recalculated after each completed trip.

### SQL Migration Plan
```sql
CREATE TABLE driver_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(driverid) ON DELETE CASCADE,
  overall_score NUMERIC(5,2) NOT NULL DEFAULT 0,
  route_adherence NUMERIC(5,2) DEFAULT 0,
  trip_completion NUMERIC(5,2) DEFAULT 0,
  schedule_adherence NUMERIC(5,2) DEFAULT 0,
  inspection_compliance NUMERIC(5,2) DEFAULT 0,
  defect_reporting NUMERIC(5,2) DEFAULT 0,
  deviation_history NUMERIC(5,2) DEFAULT 0,
  fuel_consumption NUMERIC(5,2) DEFAULT 0,
  calculated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(driver_id)
);
```

### Affected Files
| Layer | Files |
|-------|-------|
| **Swift Model** | New `Core/Models/DriverScore.swift` |
| **Service Protocol** | `Services/Protocols/TripServiceProtocol.swift` — add score recalculation |
| **Service** | `Services/TripService.swift` — implement `recalculateDriverScore(driverId:)` |
| **ViewModel** | `ReportsViewModel.swift`, `UserManagementViewModel.swift` — read real scores |
| **View** | FM driver detail, driver performance view |
| **DB** | Migration script |

---

## 7. Geofence Tracking

### Current State
Tables `geofence`, `deviation_alert`, `route_waypoints` exist. Models `Geofence`, `DeviationAlert`, `RouteWaypoint` exist. `TripService` has CRUD for all. No route corridor computation (GEOF-01) exists in the app — `ActiveTrackingView` exists but no geofence subscription.

### SRS Requirements (GEOF-01–GEOF-06)
Route corridor computation from MapKit polyline, sampled overlapping circular regions, live GPS comparison, deviation severity levels, notifications.

### What Exists vs Needs Work
| Item | Status |
|------|--------|
| DB tables | Complete |
| Models | Complete |
| Service CRUD | Complete |
| Route corridor computation | Missing |
| Real-time deviation detection | Missing |
| Deviation severity classification | Missing |
| Notifications on deviation | Partial (NotificationService exists but not wired to deviation alerts) |

### Affected Files
| Layer | Files |
|-------|-------|
| **Service** | `Services/TripService.swift` — add `computeRouteCorridor(from:to:)` using MapKit |
| **New Utility** | `Core/Services/RouteCorridorService.swift` — polyline sampling + region creation |
| **Location** | `Modules/Driver/Features/Trips/LocationManager.swift` — add deviation detection logic |
| **ViewModel** | `DriverDashboardViewModel` — wire deviation alerts |
| **Notification** | `NotificationService` — ensure deviation alerts trigger notifications |
| **View** | `ActiveTrackingView` — show deviation severity |

---

## 8. Vehicle Inspections

### Current State
`InspectionView` exists with full pre/post-trip UI. `InspectionViewModel` manages items. `InspectionItem` model exists. Inspection data is stored in `LocalDataStore` (UserDefaults) — no dedicated DB table. Photos stored in `maintenance` bucket. Work orders auto-created on failure.

### SRS Requirements (INS-01–INS-19)
Checklist same structure. Pre/post trip. Photos on fail. Work order auto-creation. Replacement vehicle selection. Post-trip must complete before trip close.

### What Exists vs Needs Work
| Item | Status |
|------|--------|
| Inspection UI | Complete |
| Inspection checklist items | Complete |
| Photo capture | Complete |
| Work order auto-creation | Complete |
| Replacement vehicle logic | Complete (needs alignment with vehicle status tags — see item 1) |
| **DB persistence of inspection results** | **Missing** — stored in UserDefaults only |
| Inspection history (INS-18) | Missing (no persisted data to query) |
| Post-trip before trip close enforcement | Partial |

### SQL Migration Plan
```sql
CREATE TABLE vehicle_inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(tripid) ON DELETE CASCADE,
  vehicle_id UUID NOT NULL REFERENCES vehicles(vin),  
  driver_id UUID NOT NULL REFERENCES drivers(driverid),
  type TEXT NOT NULL CHECK (type IN ('pre_trip', 'post_trip')),
  status TEXT NOT NULL CHECK (status IN ('passed', 'failed')),
  odometer_reading DOUBLE PRECISION,
  fuel_level DOUBLE PRECISION,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE inspection_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id UUID NOT NULL REFERENCES vehicle_inspections(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pass', 'fail')),
  fail_description TEXT,
  fail_photo_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### Affected Files
| Layer | Files |
|-------|-------|
| **Swift Model** | New `Core/Models/VehicleInspection.swift`, `InspectionItem.swift` (migrate from Driver/Features/Vehicle/) |
| **Service Protocol** | New `Services/Protocols/InspectionServiceProtocol.swift` |
| **Service** | New `Services/InspectionService.swift` |
| **ViewModel** | `InspectionViewModel.swift` — replace UserDefaults with DB persistence |
| **View** | `InspectionView.swift` — wire to service |
| **DB** | Migration script |

---

## 9. Work Order `on_hold` Status

### Current State
`MaintenanceTaskStatus` enum: `scheduled`, `assigned`, `in_progress`, `completed`, `fake`. SRS WO-01 requires: `created` → `assigned` → `in_progress` → `completed` → `verified` → `closed`.

### SRS Requirements (WO-01–WO-10)
Full lifecycle including `verified`, `closed`. No `on_hold` in current SRS — adding `on_hold` as intermediate for when MP needs FM input or parts unavailable.

### SQL Migration Plan
```sql
ALTER TABLE maintenance_task DROP CONSTRAINT IF EXISTS maintenance_task_status_check;
-- Keep existing + add verified, closed, on_hold
ALTER TABLE maintenance_task ADD CONSTRAINT maintenance_task_status_check
  CHECK (status IN ('scheduled', 'assigned', 'in_progress', 'on_hold', 'completed', 'verified', 'closed', 'fake'));
-- Add on_hold_reason, on_hold_at columns
ALTER TABLE maintenance_task ADD COLUMN on_hold_reason TEXT;
ALTER TABLE maintenance_task ADD COLUMN on_hold_at TIMESTAMPTZ;
-- Add new status timestamps
ALTER TABLE maintenance_task ADD COLUMN verified_at TIMESTAMPTZ;
ALTER TABLE maintenance_task ADD COLUMN closed_at TIMESTAMPTZ;
```

### Affected Files
| Layer | Files |
|-------|-------|
| **Swift Enum** | `Core/Enums/MaintenanceTaskStatus.swift` — `verified`, `closed`, `onHold` |
| **Swift Model** | `MaintenanceTask.swift` — `onHoldReason`, `verifiedAt`, `closedAt` |
| **Service** | `MaintenanceService.swift` — add verification and closure methods |
| **ViewModel** | Maintenance NewUI `CompleteWorkOrderViewModel` — add on_hold action |
| **View** | `CompleteWorkOrderView.swift`, WorkOrderCard — show on_hold badge |
| **DB** | Migration script |

---

## 10. Inventory CSV Import & Template

### Current State
`InventoryCSVLoader` reads from bundled `spare_parts.csv` only. No UI for importing CSVs. SRS INV-01 requires Fleet Manager upload CSV to bulk-add items.

### SRS Requirements (INV-01–INV-02)
CSV columns: `name, sku, description, category, unit, quantityOnHand, reorderLevel, unitCost`. Validate and batch insert. Error details on failure.

### Affected Files
| Layer | Files |
|-------|-------|
| **Service** | `InventoryService.swift` — add `bulkImportFromCSV(data:)` |
| **Service Protocol** | `InventoryServiceProtocol.swift` — add bulk import |
| **New Helper** | Replace `InventoryCSVLoader` with new CSV parser matching SRS column format |
| **ViewModel** | `InventoryViewModel.swift` — add import state, validation errors |
| **View** | Inventory list — add "Import CSV" button + file picker + template download |
| **Resource** | New bundled CSV template file `inventory_template.csv` |

---

## 11. Fuel & Expense Persistence

### Current State
`FuelRecord` struct is local-only (stored in `LocalDataStore`/UserDefaults). `Trip` model has `fuelCost`, `miscellaneousCost` fields. DB `trips` table has `fuel_cost`, `miscellaneous_cost` columns. SRS FEL-01–FEL-06, TOL-01–TOL-09 require full fuel entry and expense management.

### SRS Requirements
- Fuel entries: liters, cost per liter, total cost, fuel type, odometer, linked to trip (FEL-01)
- Receipt OCR: pick type (fuel/toll/parking/permit/other), capture photo, Vision OCR, review/edit (TOL-01–TOL-09)
- Fuel entry auto-links to active trip (FEL-06)

### SQL Migration Plan
```sql
CREATE TABLE expense_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(tripid) ON DELETE SET NULL,
  vehicle_id UUID NOT NULL REFERENCES vehicles(vin),
  driver_id UUID NOT NULL REFERENCES drivers(driverid),
  expense_type TEXT NOT NULL CHECK (expense_type IN ('fuel', 'toll', 'parking', 'permit', 'other')),
  
  -- Fuel-specific fields  
  liters DOUBLE PRECISION,
  cost_per_liter NUMERIC(10,2),
  fuel_type TEXT CHECK (fuel_type IN ('petrol', 'diesel', 'cng')),

  -- Common fields
  total_cost NUMERIC(12,2) NOT NULL,
  odometer_reading DOUBLE PRECISION,
  receipt_image_url TEXT,
  receipt_ocr_data JSONB,
  location_lat DOUBLE PRECISION,
  location_lng DOUBLE PRECISION,
  notes TEXT,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_expense_trip ON expense_entries(trip_id);
CREATE INDEX idx_expense_vehicle ON expense_entries(vehicle_id);
CREATE INDEX idx_expense_driver ON expense_entries(driver_id);
```

### Affected Files
| Layer | Files |
|-------|-------|
| **Swift Model** | New `Core/Models/ExpenseEntry.swift` 
| **Service Protocol** | New `Services/Protocols/ExpenseServiceProtocol.swift` |
| **Service** | New `Services/ExpenseService.swift` |
| **OCR** | `OCRService.swift` — expand to extract amount, date, receipt number, vendor name |
| **ViewModel** | `FuelViewModel.swift` — replace local storage with service calls |
| **View** | `FuelRequestView.swift`, new receipt capture flow |
| **DB** | Migration script |

---

## 12. Reports & Export

### Current State
`ReportsViewModel` computes all analytics in-memory from fetched data. `ReportsHubView` renders charts and cards. No PDF/CSV/Excel export exists.

### SRS Requirements (RPT-01–RPT-08)
- 5 predefined reports: Trip, Maintenance, Fleet Utilization, Driver Performance, Vehicle Health
- Export formats: PDF, CSV, Excel
- On-demand generation only

### Affected Files
| Layer | Files |
|-------|-------|
| **Service** | New export service or extension on existing services |
| **View** | Reports hub — add export buttons per report type |
| **New** | PDF generation using `UIGraphicsPDFRenderer` or Swift Charts snapshot |
| **New** | CSV generation as formatted String |
| **New** | Excel generation using CoreXLSX or CSV-as-xlsx |
| **ViewModel** | `ReportsViewModel.swift` — add export methods |

### Dependencies
- For Excel: Add Swift package `CoreXLSX` or use CSV-with-.xlsx-extension as minimal approach
- For PDF: Use `UIGraphicsPDFRenderer` or Swift Charts `ImageRenderer`

---

## 13. Notification Clearing

### Current State
`NotificationService` has `markAsRead` and `markAllAsRead`. No delete/clear. SRS NOT-10 requires user-clearable notifications. NOT-11 requires persistence until explicitly cleared.

### SQL Migration Plan
```sql
-- No migration needed — DELETE with proper RLS is sufficient
-- Add RLS policy for delete
CREATE POLICY "notifications_delete_own" ON notifications
  FOR DELETE USING (recipient_id = auth.uid());
```

### Affected Files
| Layer | Files |
|-------|-------|
| **Service Protocol** | `NotificationServiceProtocol.swift` — add `deleteNotification`, `clearAll` |
| **Service** | `NotificationService.swift` — implement delete methods |
| **ViewModel** | `NotificationViewModel.swift` — add delete/clear actions |
| **View** | `NotificationListView.swift` — add swipe-to-delete, "Clear All" button |

---

# Session Log

| Date | Task | Attempts | Solution | Status |
|------|------|----------|----------|--------|
| — | — | — | — | No sessions yet |

---

# Supabase RLS Strategy (Pre-requisite for all features)

Before implementing any feature, the SQL migrations should include RLS policies. Current state: RLS enabled only on `notifications`. All tables needs:

```sql
-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE fleet_manager ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_personnel ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
-- etc.

-- Tenant isolation via role + user_id lookup
-- Fleet Manager: full access to all tenant rows
-- Driver: own data only
-- Maintenance Personnel: own data + work orders
```

Additionally, the `SUPABASE_ANON_KEY` in xcconfig must be replaced with a true **anon** key (not `service_role`).

---

# Edge Functions Inventory

| Function | Status | Purpose |
|----------|--------|---------|
| `send-recovery-otp` | Exists (deployed) | Sends OTP email for password reset |
| `invite-user` | Referenced in `AuthService.inviteUser` but not in EdgeFunctions folder | Creates auth identity + sends invite email |
| `force-update-password` | Referenced in `AuthService.forceUpdatePassword` but not in EdgeFunctions folder | Admin force-update user password |
| `delete-user` | Referenced in `AuthService.deleteUserAuth` but not in EdgeFunctions folder | Cascade delete user auth + data |

Edge functions `invite-user`, `force-update-password`, and `delete-user` are referenced by `AuthService` but their source code is not in the repository. These must be recovered from the deployed functions or re-created.
