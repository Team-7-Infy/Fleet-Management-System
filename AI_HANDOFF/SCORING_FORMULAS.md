# Scoring Formulas

## Driver Score (4 Factors)

Calculated by `UserManagementService.calculateAndUpsertDriverScore(driverId:)`.

Called from:
- `TripManagementViewModel.updateStatus(.completed)` — when trip is completed
- `LocationManager.triggerDeviationAlert` — when a geofence breach occurs

### Formula

```
overallScore = (inspectionFalseRate * 0.25)
             + (geofenceViolationRate * 0.25)
             + (complianceViolationRate * 0.25)
             + (mileageAccuracy * 0.25)
```

Each factor is normalized to 0–100. The overall score is also 0–100.

### Factor 1: Inspection False Rate (25%)

```
falseInspections = trips where inspection was completed but had items failed
successfulTrips  = total completed trips by this driver

rate = (successfulTrips > 0) ? ((1 - falseInspections / successfulTrips) * 100) : 0
```

**DB query**: Count of `vehicle_inspections` where `driver_id = ? AND type = 'post_trip' AND status = 'passed'` divided by total completed trips count from `trips` table where `driverid = ? AND status = 'completed'`.

**Edge case**: If 0 completed trips, score = 0 (neutral, won't penalize but won't help).

### Factor 2: Geofence Violation Rate (25%)

```
violations  = count of deviation_alert for trips by this driver
totalTrips  = completed trips by this driver

rate = (totalTrips > 0) ? ((1 - violations / totalTrips) * 100) : 100
```

**DB query**: Count of `deviation_alert` joined with `trips` where driver matches.

**Edge case**: If 0 completed trips, score = 100 (no violations to have).

### Factor 3: Compliance Violation Rate (25%)

```
overdueTrips = trips where endTime > trip.startTime + 8 hours*
totalTrips   = completed trips

rate = (totalTrips > 0) ? ((1 - overdueTrips / totalTrips) * 100) : 0

* If scheduledEndTime or endTime is nil, uses fixed 8-hour window from startTime
```

**DB query**: Aggregation of trip data with fallback duration comparison.

**Edge case**: If 0 trips, score = 0. If an `endTime` or `scheduledEndTime` is `nil`, the formula falls back to comparing `endTime` against `startTime + 8 hours` (hardcoded standard shift).

### Factor 4: Mileage Accuracy (25%)

```
kilometersArray = array of trip distanceKm values (from completed trips)
mean = average of non-nil, non-zero distances
if mean == 0: return 0 (no data)

variance = sum((dist - mean)^2) for each non-nil/non-zero dist / count
stdDev = sqrt(variance)
cv = stdDev / mean

// Convert coefficient of variation to 0-100 score
// Lower cv (more consistent) = higher score
rate = max(0, min(100, (1 - cv) * 100))
```

**Edge case**: If fewer than 2 trips have `distanceKm` values, returns 0 (insufficient data).

### DB Record

```sql
INSERT INTO driver_scores (driver_id, overall_score, inspection_false_rate,
  geofence_violation_rate, compliance_violation_rate, mileage_accuracy,
  calculated_at)
VALUES ($1, $2, $3, $4, $5, $6, now())
ON CONFLICT (driver_id) DO UPDATE SET
  overall_score = EXCLUDED.overall_score,
  inspection_false_rate = EXCLUDED.inspection_false_rate,
  geofence_violation_rate = EXCLUDED.geofence_violation_rate,
  compliance_violation_rate = EXCLUDED.compliance_violation_rate,
  mileage_accuracy = EXCLUDED.mileage_accuracy,
  calculated_at = now();
```

---

## Vehicle Health Score (5 Factors)

Calculated by `VehicleService.fetchVehicleHealthScores()`. Returns an array of `VehicleHealthScore` structs (one per vehicle).

### Formula

```
overallScore = (fleetTenure * 0.20)
             + (fuelEfficiency * 0.20)
             + (maintenanceAdherence * 0.20)
             + (defectHistory * 0.20)
             + (criticalRepairs * 0.20)
```

### Factor 1: Fleet Tenure / Age (20%)

```
tenureDays = days since vehicle was added (added_to_fleet_at) or vehicle model year

if tenureDays > 0:
  // Normalize to 100-point scale, assuming max useful life = 10 years (3650 days)
  score = (1 - min(tenureDays, 3650) / 3650) * 100
else:
  score = 50 // unknown tenure
```

**DB query**: `added_to_fleet_at` or `year` column from `vehicles` table.

**Edge case**: If `added_to_fleet_at` is nil, falls back to `year` column (uses July 1 of that year). If `year` is also nil, score = 50.

### Factor 2: Fuel Efficiency Trend (20%)

```
trips = completed trips with distanceKm and fuel cost data
kmPerLiter = total distance / total spent (no fuel_entries table)

rate = kmPerLiter / expectedKmPerLiter * 100
capped at min(0, max(100, rate))

Expected values by fuel type:
  petrol: 12 km/L
  diesel: 15 km/L
  CNG:    20 km/kg
  nil:    12 km/L (fallback)
```

**DB query**: Aggregate `distanceKm` per trip from `trips` table, fuel cost from `trips.fuel_cost`.

**Edge case**: If no trips have both distance and fuel cost, score = 50 (unknown).

### Factor 3: Maintenance Adherence (20%)

```
completedTasks = count of maintenance_task for this vehicle where status = 'completed'
totalTasks    = count of maintenance_task for this vehicle (all statuses except 'fake')
scheduledTask = count of maintenance_task for this vehicle where status = 'completed'

rate = (totalTasks > 0) ? (completedTasks / totalTasks) * 100 : 100
```

**DB query**: `maintenance_task` table joined with `task_vehicles`.

**Edge case**: No tasks for this vehicle → score = 100 (perfect record).

### Factor 4: Defect / Inspection History (20%)

```
passedInspections = count of vehicle_inspections where status = 'passed'
totalInspections  = count of all vehicle_inspections for this vehicle

rate = (totalInspections > 0) ? (passedInspections / totalInspections) * 100 : 100
```

**DB query**: `vehicle_inspections` table.

**Edge case**: No inspections for this vehicle → score = 100 (perfect record).

### Factor 5: Critical Repairs Burden (20%)

```
totalRepairCost = SUM of completed maintenance tasks' total cost for this vehicle
vehicleAgeInYears = from added_to_fleet_at or year (min 1 year)

rate = max(0, min(100, (1 - (totalRepairCost / 50000) / vehicleAgeInYears) * 100))

// 50000 = critical cost mark in rupees
```

**DB query**: `maintenance_task` table joined with `task_vehicles`.

**Edge case**: No completed maintenance tasks → score = 100. If totalRepairCost is 0 → score = 100.

---

## Trip Auto-Assignment

Called from `TripManagementViewModel.autoAssign(trip:)`.

### Eligible Vehicle Filtering

```
1. vehicles where vehicleType == trip.vehicleTypeRequested
2. status == 'available'
3. deletedAt == nil
4. Sort by totalTripCount ASC (least used first)
5. Pick the first (least-used)
```

**Edge case**: If no eligible vehicle, creates notification "Trip X could not be auto-assigned" and exits early (no driver assignment either).

### Driver Ranking Algorithm

Once vehicle is assigned, rank eligible drivers:

```
eligibility:
  1. driver's vehicleType matches trip's vehicleTypeRequested
  2. driver's user.isActive == true
  3. driver's user.deletedAt == nil

scoreRank = normalized(0-1) from driverScore.overallScore (divide by 100)
workloadRank = normalized(0-1) from count of active trips (1 - activeTrips/maxActiveTrips)
scheduleRank = 0 or 1 based on whether any schedule covers the trip start time

compositeScore = scoreRank * 0.5 + workloadRank * 0.3 + scheduleRank * 0.2

Pick driver with highest compositeScore.
```

**No-inspection check**: If driver ranking yields no candidate, creates notification and exits without assigning.

### Reassignment on Rejection

Called from `TripManagementViewModel.approveRejection(trip:)`:

```
1. Set old vehicle back to 'available'
2. Find next eligible vehicle (same criteria as above, excluding previously assigned VIN)
3. Re-rank drivers excluding the one who rejected
4. Assign new driver + vehicle to trip
5. Update trip status back to 'scheduled'
6. Create notification to new driver
```

**Edge case**: If no eligible replacement driver/vehicle, keeps trip as `rejectionPending` and creates notification to FM.

---

## Work Order Auto-Assignment

Called from `WorkOrderAssignmentService.findBestPersonnel()`:

```
eligiblePersonnel = maintenance_personnel where isActive true
                    joined to users where deletedAt is nil

for each eligible personnel:
  openCount = count of maintenance_task where executedby = personnelId
              AND status IN ('scheduled', 'assigned', 'in_progress', 'on_hold')

Pick personnel with lowest openCount.

If tie: pick first alphabetically by name.
```

**Edge case**: No eligible personnel → returns nil, creates notification to FM. Currently only logged (not surfaced in UI).
