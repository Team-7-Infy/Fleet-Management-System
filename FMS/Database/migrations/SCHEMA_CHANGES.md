# Schema & Model Changes — Reports & Analytics Feature

## Migration: `20260703_reporting_schema_fields.sql`

### New Database Columns

#### `trips`

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `distance_km` | `numeric(10,2)` | `NULL` | Actual distance covered during the trip (km) |
| `fuel_cost` | `numeric(12,2)` | `0` | Total fuel cost logged for this trip |
| `miscellaneous_cost` | `numeric(12,2)` | `0` | Non-fuel expenses (toll, parking, permit, other) |

#### `vehicles`

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `added_to_fleet_at` | `timestamptz` | `now()` | Date the vehicle was added to the system (used for health score age calculation — distinct from `year` which is manufacture year) |

#### `inventory`

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `sku` | `text` | `NULL` | Stock-keeping unit identifier (from CSV import, INV-02) |
| `description` | `text` | `NULL` | Detailed description of the inventory item |
| `category` | `text` | `NULL` | Item category for filtering (e.g., Tyres, Filters, Brakes) |
| `unit` | `text` | `NULL` | Unit of measure (e.g., piece, litre, set) |
| `reorderlevel` | `integer` | `0` | Minimum quantity before reorder is triggered |
| `unitcost` | `numeric(12,2)` | `NULL` | Cost per unit (may differ from `inventory.cost` which is average) |

#### `maintenance_task`

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `labour_cost` | `numeric(12,2)` | `0` | Labour cost portion of the work order (separate from parts cost in `totalcost`) |

### New Indexes

- `idx_trips_starttime_status` on `trips (starttime desc, status)` — speeds up period-filtered trip queries
- `idx_trips_completed_cost` on `trips (status, endtime desc)` WHERE `status = 'completed'` — speeds up completed trip cost aggregation
- `idx_maintenance_task_cost_labour` on `maintenance_task (totalcost, labour_cost)` — speeds up maintenance cost aggregation

---

## Swift Model Changes

### `Trip.swift` — New Fields

```swift
var distanceKm: Double?
var fuelCost: Double?
var miscellaneousCost: Double?
```

Added computed property:
```swift
var totalCost: Double { (fuelCost ?? 0) + (miscellaneousCost ?? 0) }
```

### `Vehicle.swift` — New Field

```swift
var addedToFleetAt: Date?
```

### `MaintenanceTask.swift` — New Field

```swift
var labourCost: Double?
```

### `InventoryPart.swift` — New Fields

```swift
var sku: String?
var partDescription: String?
var category: String?
var unit: String?
var reorderLevel: Int?
var unitCost: Double?
```

### `FleetManagerForms.swift` — Updated Initializers

- `FleetManagerTripForm.makeTrip()` now passes `distanceKm: nil, fuelCost: nil, miscellaneousCost: nil`
- `FleetManagerVehicleForm.makeVehicle()` now passes `addedToFleetAt: Date()`
- `FleetManagerMaintenanceTaskForm.makeTask()` now passes all optional fields explicitly including `labourCost: nil`

### `MaintenanceService.swift` — Updated RPC Mapping

The `fetchTasksForPersonnel` RPC mapping now includes `labourCost: nil` in the `MaintenanceTask` initializer.

---

## New Files Created

| File | Purpose |
|------|---------|
| `ViewModels/ReportsViewModel.swift` | Central ViewModel for all reports/analytics data, period filtering, KPI computation |
| `Views/Reports/ReportsHubView.swift` | Full hub screen showing 5 category cards with Swift Charts |
| `Views/Reports/Components/ReportSummaryCard.swift` | Dashboard summary card (3 used in the Live tab) |
| `Views/Reports/Components/ReportCategoryCard.swift` | Hub category card wrapper |
| `Views/Reports/Components/PeriodFilterPicker.swift` | Reusable period filter (1M/3M/6M/1Y) |
| `Views/Reports/Details/TripReportDetailView.swift` | Trip report detail with weekly chart, punctuality, fuel expenditure |
| `Views/Reports/Details/MaintenanceReportDetailView.swift` | Maintenance report with cost breakdown, longest/most expensive work orders |
| `Views/Report/Details/FleetUtilizationDetailView.swift` | Vehicle utilization chart and trip counts |
| `Views/Report/Details/DriverPerformanceDetailView.swift` | Driver trip distribution chart and breakdown |
| `Views/Report/Details/VehicleHealthDetailView.swift` | Vehicle health score chart and detailed list |

## Modified Files

| File | Changes |
|------|---------|
| `ManagerOverviewView.swift` | Removed `Pending Trips` / `Completed Trips` metric cards. Removed `tripMetricsRow`, `pendingTrips`, `completedTrips` properties. Added `Reports & Analytics` section with 3 `ReportSummaryCard` widgets. Added `ReportsViewModel` as `@StateObject`. Added `onShowReportsHub` callback. |
| `FleetManagerDashboardView.swift` | Added `isShowingReportsHub` state. Updated `liveTab` to pass `onShowReportsHub` and add `.navigationDestination` for `ReportsHubView`. |

---

## Future Enhancements (Scoring Data Pipeline)

The following data points are not yet collected but are needed for complete scoring as specified in the SRS:

1. **Driver Score (DSC-01)**: Route adherence, inspection compliance, defect reporting accuracy — requires:
   - `inspection_results` table (pre/post trip inspections with pass/fail per item)
   - Driver score recalculation logic in a Supabase RPC or Edge Function

2. **Vehicle Health Score (VHS-01)**: Fuel efficiency trend, defect history, critical repair frequency — requires:
   - `fuel_entries` table (liters, cost per liter, odometer reading) for efficiency tracking
   - Defect report approval/rejection tracking (MNT-11)
   - Critical work order flagging (WO-04)

3. **Trip Expenses**: Fuel entries and toll receipts — requires:
   - `fuel_entries` table (FEL-01 through FEL-06)
   - `expense_entries` table (TOL-01 through TOL-09)
   - Receipt image storage and OCR processing

4. **Inventory CSV Import (INV-02)**: The `sku`, `description`, `category`, `unit`, `reorderLevel`, and `unitCost` columns are added to support the CSV import, but the import logic itself is not yet implemented.

The current Fleet Health score on the dashboard is a **simplified version** using available data (vehicle status distribution, open maintenance task count). A `labourCost` column has been added to `maintenance_task` so that the Maintenance Expenditure report can track labour vs parts costs separately.
