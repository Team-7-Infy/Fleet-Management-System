# Implementation Progress

## Legend

| Status | Meaning |
|--------|---------|
| ✅ Complete | Fully implemented, tested, committed |
| 🔶 Partial | Implemented but has gaps or known issues |
| ❌ Not Started | Not yet implemented |
| 🚫 Excluded | Intentional out-of-scope decision |

---

## Auth & Onboarding

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Email/password login | ✅ | AuthService.swift, LoginView.swift | None |
| Sign up (FM self-registration) | ✅ | AuthService.signUp | None |
| Invite user (edge function) | ✅ | AuthService.inviteUser | Edge function source not in repo |
| Forgot password / OTP | ✅ | AuthService.sendRecoveryOTP/verifyOTP, ForgotPasswordView | None |
| First-time setup profile | ✅ | FirstTimeSetupView, AuthService.completeFirstTimeProfile | None |
| Session restore | ✅ | AppRouter, AuthService.currentSession | None |
| Force update password | ✅ | AuthService.forceUpdatePassword | Edge function source not in repo |
| Delete user auth | ✅ | AuthService.deleteUserAuth | Edge function source not in repo |
| OAuth/Social login | 🚫 | N/A | Excluded from SRS |
| Multi-factor auth | 🚫 | N/A | Excluded |

---

## User Management

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Create user (any role) | ✅ | UserManagementViewModel.createUser | None |
| Update user profile | ✅ | UserManagementViewModel.updateUser, updateDriverProfile | None |
| Soft delete user | ✅ | UserManagementService.deleteUser (sets deleted_at + isactive=false) | None |
| User list with filters | ✅ | ManagerUsersView | None |
| Role rows preserved on delete | ✅ | deleteDriverByUserId (no-op) | None |
| Driver score display | ✅ | UserManagementViewModel.driverScore, averageDriverScore | None |
| Schedule management | ✅ | UserManagementService.create/delete/fetchDriverSchedules | None |

---

## Vehicle Management

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Vehicle CRUD | ✅ | VehicleService, VehicleViewModel | None |
| Vehicle status tags | ✅ | VehicleStatus enum (4 values), migration | None |
| Vehicle add/edit form | ✅ | ManagerVehicleFormSheet (fuel type, intervals, type) | None |
| Compliance docs | ✅ | VehicleDocument model, VehicleComplianceDocsView | None |
| Soft delete (archive) | ✅ | VehicleService.deleteVehicle (sets deleted_at) | None |
| Set out of service | ✅ | VehicleService.setOutOfService | None |
| Assign/unassign driver | ✅ | VehicleService.assignDriver/unassignDriver | None |
| Vehicle health scores | ✅ | VehicleService.fetchVehicleHealthScores (5 factors) | None |
| Demo record filtering | ✅ | VehicleViewModel.isPlaceholderDemoRecord | Remove when demo data cleaned |

---

## Trip Management

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Trip CRUD | ✅ | TripService, TripManagementViewModel | None |
| Trip creation (no driver/vehicle select) | ✅ | ManagerTripFormSheet (vehicle type only) | None |
| Trip lifecycle states | ✅ | TripStatus enum (8 values) | None |
| Auto-assignment (score/workload/schedule) | ✅ | TripManagementViewModel.autoAssign | None |
| Rejection approval auto-reassignment | ✅ | TripManagementViewModel.approveRejection | None |
| Rejection deny | ✅ | TripManagementViewModel.denyRejection | None |
| Driver accept trip | ✅ | DashboardView.acceptTrip | None |
| Driver reject trip | ✅ | DashboardView.rejectTrip, RejectTripSheet | None |
| Trip completion (score recalc) | ✅ | TripManagementViewModel.updateStatus(.completed) | None |
| Real-time trip updates (driver) | ✅ | TripService.subscribeToTrips | None |

---

## Active Trip Tracking & Geofence

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Real GPS navigation | ✅ | LocationManager, ActiveNavigationDetailView | None |
| Active-trip-only tracking | ✅ | LocationManager.startTracking with trip context | None |
| Adaptive frequency | ✅ | LocationManager.updateTrackingFrequency | None |
| Background location | ✅ | allowsBackgroundLocationUpdates = true | None |
| Heading tracking | ✅ | startUpdatingHeading, heading property | None |
| Local telemetry buffering | ✅ | pendingTelemetryBuffer (NSLock, 500 cap) | None |
| Telemetry DB persistence | ✅ | logTelemetry (tripid, vehicleid, heading) | None |
| Route waypoint generation | ✅ | RouteCorridorService, generateAndPersistWaypoints | None |
| Deviation detection & alert | ✅ | LocationManager.checkDeviation, triggerDeviationAlert | None |
| Deviation notification | ✅ | Alerts FM users via NotificationService | None |
| Scoring hook on breach | ✅ | Triggers calculateAndUpsertDriverScore | None |
| Severity classification | 🚫 | N/A | Intentional exclusion |
| Driver score impact from geofence | ✅ | geofence_violation_rate factor in driver score | None |

---

## Inspections

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Pre-trip inspection checklist | ✅ | InspectionView, InspectionViewModel | None |
| Failed items require text + photo | ✅ | InspectionViewModel.isComplete check | None |
| Pre-trip inspection persistence | ✅ | persistInspection → InspectionService | None |
| Post-trip inspection checklist | ✅ | EndTripView (rewritten with items) | None |
| Post-trip odometer + fuel reading | ✅ | EndTripView (mandatory fields) | None |
| Post-trip persistence | ✅ | EndTripView.submitTrip | None |
| Work order creation on failure | ✅ | Both pre/post create work orders | None |
| Work order auto-assignment | ✅ | WorkOrderAssignmentService.findBestPersonnel | None |
| Inspection history | 🔶 | Inspections persisted but no history view | Add inspection history UI |
| InspectionItem model (local) | 🔶 | InspectionItem.swift (driver feature) coexists with InspectionItemDB (model) | Consolidate models |

---

## Fuel & Expenses

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Fuel types (petrol/diesel/cng) | ✅ | FuelRecord, Vehicle, ExpenseEntry | None |
| CNG support (kg units) | ✅ | FuelRecord.refillUnit/priceUnit, ExpenseEntry.quantityUnit | None |
| Fuel entry to Supabase | ✅ | ExpenseService.createExpense | None |
| Receipt OCR (amount/date/vendor/number) | ✅ | OCRService.extractReceiptInfo | None |
| OCR review before save | ✅ | OCRReviewView (editable) | None |
| Expense entries linked to trip/vehicle/driver | ✅ | ExpenseEntry model | None |
| Fuel history view | ✅ | TripFuelHistoryView, FuelHistoryView | None |
| EV removed | ✅ | Migration, model, UI | None |
| FM fuel approval flow | 🔶 | Remains in LocalDataStore | Wire to Supabase if needed |

---

## Inventory

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Inventory part CRUD | ✅ | InventoryService, InventoryPart | None |
| CSV import (Fleet Manager only) | ✅ | InventoryCSVParser, ManagerMaintenanceView toolbar | None |
| CSV template download | ✅ | generateTemplateCSV, ShareLink | None |
| Validation (header, rows, SKU) | ✅ | InventoryCSVParser.parse | None |
| Batch insert | ✅ | InventoryService.bulkImportFromCSV | None |
| Low-stock quotation | ✅ | generateLowStockQuotationCSV | None |
| Threshold detection | ✅ | ThresholdStore, InventoryThresholdSheet | None |
| Purchase orders | 🚫 | N/A | Intentionally excluded |

---

## Reports & Export

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Report periods (2M/4M/8M/1Y) | ✅ | PeriodPreset enum | None |
| Trip report | ✅ | ReportsViewModel, TripReportDetailView | None |
| Expenditure report | ✅ | ReportsViewModel, ExpenditureDetailView | None |
| Fleet Utilization report | ✅ | ReportsViewModel, FleetUtilizationDetailView | None |
| Driver Performance report | ✅ | ReportsViewModel, DriverPerformanceDetailView | None |
| Vehicle Health report | ✅ | ReportsViewModel, VehicleHealthDetailView | None |
| Maintenance report | ✅ | ReportsViewModel, MaintenanceReportDetailView | None |
| CSV export | ✅ | ReportExporter (all 6 report types) | None |
| PDF export | ✅ | ReportExporter (UIGraphicsPDFRenderer) | None |
| Excel (.xlsx) export | 🚫 | N/A | CSV accepted as Excel-compatible |
| Report share button | ✅ | ReportExportToolbarItem (ShareLink) | None |

---

## Notifications

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Fetch notifications | ✅ | NotificationService.fetchNotifications | None |
| Create notification | ✅ | NotificationService.createNotification | None |
| Mark as read | ✅ | NotificationService.markAsRead | None |
| Mark all as read | ✅ | NotificationService.markAllAsRead | None |
| Delete notification | ✅ | NotificationService.deleteNotification | None |
| Clear all (delete) | ✅ | NotificationService.clearAllNotifications | None |
| Realtime subscription | ✅ | NotificationService.subscribeToRealtime | None |
| Trip realtime subscription | ✅ | NotificationService.subscribeToTripsRealtime | None |
| Local banner queue | ✅ | NotificationViewModel.enqueueBanner | None |
| Haptic feedback | ✅ | triggerHapticFeedback | None |
| Targeted recipients (not broadcast) | ✅ | All event notifications use explicit recipientId | None |
| Trip assignment notification | ✅ | FleetManagerDashboardView → driver userId | None |
| Reassignment notification | ✅ | → new driver userId | None |
| Rejection denied notification | ✅ | → original driver userId | None |
| Rejection request → FM | ✅ | → FM userId | None |
| Geofence deviation → FM | ✅ | → FM userId | None |
| Inspection failure → FM | ✅ | → FM userId | None |
| Work-order status → FM/Personnel | ✅ | → FM userId | None |
| Low-stock → FM | ✅ | → FM userId | None |

---

## Maintenance Work Orders

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Work order CRUD | ✅ | MaintenanceService, MaintenanceViewModel | None |
| Status lifecycle (scheduled→assigned→in_progress→on_hold→completed/fake) | ✅ | MaintenanceTaskStatus, SupabaseWorkOrderService | None |
| on_hold with reason | ✅ | holdTask/unholdTask, on_hold_reason/at | None |
| Auto-assignment to personnel | ✅ | WorkOrderAssignmentService, wired in createTask, InspectionView, EndTripView | None |
| Open screen → in_progress (by design) | ✅ | CompleteWorkOrderViewModel.onAppear | None |
| Fake completion | ✅ | Status enum, CompleteWorkOrderScreen | None |
| Parts tracking | ✅ | MaintenanceTaskPart, TaskVehicle, AddPartsSheet | None |
| verified/closed status | 🚫 | N/A | Intentionally excluded |

---

## Driver Scoring

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| 4-factor score calculation | ✅ | UserManagementService.calculateAndUpsertDriverScore | None |
| Inspection false rate | ✅ | Queries vehicle_inspections | None |
| Geofence violation rate | ✅ | Queries deviation_alert per completed trip | None |
| Compliance violation rate | ✅ | Compares endTime to expected duration | None |
| Mileage accuracy | ✅ | Coefficient of variation of distanceKm | None |
| Score recalculation on trip completion | ✅ | TripManagementViewModel.updateStatus(.completed) | None |
| Score recalculation on geofence breach | ✅ | LocationManager.triggerDeviationAlert | None |
| Score used in auto-assignment | ✅ | TripManagementViewModel.rankDrivers | None |
| Score display in reports | ✅ | ReportsViewModel, DriverPerformanceDetailView | None |

---

## Vehicle Health Scoring

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| 5-factor score calculation | ✅ | VehicleService.fetchVehicleHealthScores | None |
| Fleet tenure/age | ✅ | addedToFleetAt or year | None |
| Fuel efficiency trend | ✅ | km per liter vs expected by fuel type | None |
| Maintenance adherence | ✅ | completed/total task ratio | None |
| Defect/inspection history | ✅ | passed/total inspection ratio | None |
| Critical repairs burden | ✅ | total cost normalized to ₹50k | None |
| Score display in reports | ✅ | VehicleHealthDetailView | None |

---

## Tests

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Unit tests | ❌ | FMSTests.swift (template) | Add meaningful tests |
| UI tests | ❌ | FMSUITests.swift (template) | Add meaningful tests |
| CSV parser tests | ❌ | N/A | High-value test target |
| Scoring logic tests | ❌ | N/A | High-value test target |

---

## Security & Infrastructure

| Feature | Status | Files | Remaining Work |
|---------|--------|-------|----------------|
| Secrets in xcconfig | ❌ | Secrets.debug/release.xcconfig | Rotate key, remove from repo, add to .gitignore |
| RLS policies | 🔶 | Only notifications + 6 new tables | Full RLS audit needed for all tables |
| Multi-tenancy | ❌ | N/A | No tenant model exists |
| Edge function sources | 🔶 | 2 of 5 in repo | Add missing 3 functions or remove references |
| Test coverage | ❌ | N/A | No meaningful tests |
| NavigationView (deprecated) | 🔶 | Driver/MainTabView.swift | Replace with NavigationStack |
| Duplicate migration path | 🔶 | FMS/FMS/Database/migrations/ (1 file) | Consolidate into FMS/Database/migrations/ |
