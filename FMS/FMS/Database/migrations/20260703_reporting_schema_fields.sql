begin;

-- ============================================================
-- Migration: Reporting schema fields
-- Date: 2026-07-03
-- Description: Adds columns needed for Fleet Manager reporting
-- and analytics (Fuel Expenditure, Trip Punctuality,
-- Maintenance Costs, Fleet Health, Inventory tracking).
-- ============================================================

-- 1. trips — cost and distance tracking for Trip Reports & Fuel Expenditure
alter table public.trips
    add column if not exists distance_km numeric(10, 2),
    add column if not exists fuel_cost numeric(12, 2) default 0,
    add column if not exists miscellaneous_cost numeric(12, 2) default 0;

comment on column public.trips.distance_km is 'Actual distance covered during the trip (km).';
comment on column public.trips.fuel_cost is 'Total fuel cost logged for this trip (sum of linked fuel entries).';
comment on column public.trips.miscellaneous_cost is 'Non-fuel expenses (toll, parking, permit, other) for this trip.';

-- 2. vehicles — fleet tenure tracking for Vehicle Health Score (age factor)
alter table public.vehicles
    add column if not exists added_to_fleet_at timestamptz default now();

comment on column public.vehicles.added_to_fleet_at is 'Date the vehicle was added to the fleet system (used for health score age calculation).';

-- 3. inventory — CSV import fields matching INV-02 specification
alter table public.inventory
    add column if not exists sku text,
    add column if not exists description text,
    add column if not exists category text,
    add column if not exists unit text,
    add column if not exists reorderlevel integer default 0,
    add column if not exists unitcost numeric(12, 2);

comment on column public.inventory.sku is 'Stock-keeping unit identifier.';
comment on column public.inventory.description is 'Detailed description of the inventory item.';
comment on column public.inventory.category is 'Item category for filtering (e.g., Tyres, Filters, Brakes).';
comment on column public.inventory.unit is 'Unit of measure (e.g., piece, litre, set).';
comment on column public.inventory.reorderlevel is 'Minimum quantity before reorder is triggered.';
comment on column public.inventory.unitcost is 'Cost per unit (may differ from inventory.cost which is average).';

-- 4. maintenance_task — labour cost separation for Maintenance Expenditure reports
alter table public.maintenance_task
    add column if not exists labour_cost numeric(12, 2) default 0;

comment on column public.maintenance_task.labour_cost is 'Labour cost portion of the work order (separate from parts cost in totalcost).';

-- Indexes for report query performance
create index if not exists idx_trips_starttime_status
    on public.trips (starttime desc, status);

create index if not exists idx_trips_completed_cost
    on public.trips (status, endtime desc)
    where status = 'completed';

create index if not exists idx_maintenance_task_cost_labour
    on public.maintenance_task (totalcost, labour_cost);

commit;
