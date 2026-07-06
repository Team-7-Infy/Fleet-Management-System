create table if not exists public.expense_entries (
    id uuid primary key default gen_random_uuid(),
    trip_id uuid references public.trips(tripid) on delete set null,
    vehicle_id uuid not null references public.vehicles(vin),
    driver_id uuid not null references public.drivers(driverid),
    expense_type text not null check (expense_type in ('fuel', 'toll', 'parking', 'permit', 'other')),
    liters double precision,
    cost_per_liter numeric(10, 2),
    fuel_type text check (fuel_type in ('petrol', 'diesel', 'cng')),
    total_cost numeric(12, 2) not null,
    odometer_reading double precision,
    receipt_image_url text,
    receipt_ocr_data jsonb,
    location_lat double precision,
    location_lng double precision,
    notes text,
    created_at timestamptz not null default now()
);

create index if not exists idx_expense_trip on public.expense_entries(trip_id);
create index if not exists idx_expense_vehicle on public.expense_entries(vehicle_id);
create index if not exists idx_expense_driver on public.expense_entries(driver_id);
