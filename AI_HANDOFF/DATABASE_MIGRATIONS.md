# Database Migrations

All migrations are in `FMS/Database/migrations/`. Apply in order (timestamp prefix).

**IMPORTANT**: There is also a duplicate path `FMS/FMS/Database/migrations/` with a single migration. Do not use it.

---

## 1. `20260707_vehicle_status_enum.sql`

```sql
ALTER TABLE vehicles DROP CONSTRAINT IF EXISTS vehicles_status_check;
ALTER TABLE vehicles ADD CONSTRAINT vehicles_status_check
  CHECK (status IN ('available', 'assigned', 'in_maintenance', 'out_of_service'));

UPDATE vehicles SET status = 'available' WHERE status = 'active';
UPDATE vehicles SET status = 'in_maintenance' WHERE status = 'maintenance';
-- 'inactive' records with no matching new value → default to 'available'
UPDATE vehicles SET status = 'available' WHERE status NOT IN ('available', 'assigned', 'in_maintenance', 'out_of_service');
```

---

## 2. `20260707_soft_delete.sql`

```sql
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;
ALTER TABLE vehicles ADD COLUMN deleted_at TIMESTAMPTZ;
```

---

## 3. `20260707_vehicle_documents.sql`

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
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_vehicle_docs_vehicle ON vehicle_documents(vehicle_id);
CREATE INDEX idx_vehicle_docs_expiry ON vehicle_documents(expiry_date);
```

---

## 4. `20260707_driver_scores.sql`

```sql
CREATE TABLE driver_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(driverid) ON DELETE CASCADE,
  overall_score NUMERIC(5,2) NOT NULL DEFAULT 0,
  inspection_false_rate NUMERIC(5,2) DEFAULT 0,
  geofence_violation_rate NUMERIC(5,2) DEFAULT 0,
  compliance_violation_rate NUMERIC(5,2) DEFAULT 0,
  mileage_accuracy NUMERIC(5,2) DEFAULT 0,
  calculated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(driver_id)
);
```

---

## 5. `20260707_driver_schedules.sql`

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

---

## 6. `20260707_vehicle_inspections.sql`

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

---

## 7. `20260707_expense_entries.sql`

```sql
CREATE TABLE expense_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID REFERENCES trips(tripid) ON DELETE SET NULL,
  vehicle_id UUID NOT NULL REFERENCES vehicles(vin),
  driver_id UUID NOT NULL REFERENCES drivers(driverid),
  expense_type TEXT NOT NULL CHECK (expense_type IN ('fuel', 'toll', 'parking', 'permit', 'other')),

  liters DOUBLE PRECISION,
  cost_per_liter NUMERIC(10,2),
  fuel_type TEXT CHECK (fuel_type IN ('petrol', 'diesel', 'cng')),

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

---

## 8. `20260707_maintenance_task_on_hold.sql`

```sql
ALTER TABLE maintenance_task DROP CONSTRAINT IF EXISTS maintenance_task_status_check;
ALTER TABLE maintenance_task ADD CONSTRAINT maintenance_task_status_check
  CHECK (status IN ('scheduled', 'assigned', 'in_progress', 'on_hold', 'completed', 'verified', 'closed', 'fake'));

ALTER TABLE maintenance_task ADD COLUMN on_hold_reason TEXT;
ALTER TABLE maintenance_task ADD COLUMN on_hold_at TIMESTAMPTZ;
ALTER TABLE maintenance_task ADD COLUMN verified_at TIMESTAMPTZ;
ALTER TABLE maintenance_task ADD COLUMN closed_at TIMESTAMPTZ;
```

---

## 9. `20260707_inventory_schema.sql`

```sql
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(12,2);
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS low_stock_threshold INTEGER DEFAULT 10;
```

---

## 10. `20260707_telemetry_log_extended.sql`

```sql
ALTER TABLE telemetry_log ADD COLUMN IF NOT EXISTS tripid UUID REFERENCES trips(tripid) ON DELETE SET NULL;
ALTER TABLE telemetry_log ADD COLUMN IF NOT EXISTS vehicleid UUID REFERENCES vehicles(vin) ON DELETE SET NULL;
ALTER TABLE telemetry_log ADD COLUMN IF NOT EXISTS heading REAL;
```

---

## 11. `20260707_trips_vehicleid_nullable.sql`

```sql
ALTER TABLE trips ALTER COLUMN vehicleid DROP NOT NULL;
```

---

## 12. `20260707_vehicle_fuel_type_check.sql`

```sql
ALTER TABLE vehicles DROP CONSTRAINT IF EXISTS vehicles_fuel_type_check;
ALTER TABLE vehicles ADD CONSTRAINT vehicles_fuel_type_check
  CHECK (fuel_type IN ('petrol', 'diesel', 'cng'));
UPDATE vehicles SET fuel_type = 'petrol' WHERE fuel_type NOT IN ('petrol', 'diesel', 'cng');
```

---

## 13. `20260707_vehicle_maintenance_intervals.sql`

```sql
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS maintenance_km_interval INTEGER;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS maintenance_month_interval INTEGER;
```

---

## 14. `20260707_notification_delete_rls.sql`

```sql
CREATE POLICY "notifications_delete_own" ON notifications
  FOR DELETE USING (recipient_id = auth.uid());
```

---

## 15. `20260707_phase1_table_permissions.sql`

```sql
ALTER TABLE vehicle_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspection_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_entries ENABLE ROW LEVEL SECURITY;
```

---

## Migration Order

1–15 as listed above. The number prefix matches chronological migration file names. If working from a fresh DB, apply in order. If the DB already has changes applied, verify each migration's idempotency (`IF NOT EXISTS`, `DROP CONSTRAINT IF EXISTS`, etc.).
