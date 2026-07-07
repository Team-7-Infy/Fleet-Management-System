create table if not exists public.vehicle_inspections (
    id uuid primary key default gen_random_uuid(),
    trip_id uuid not null references public.trips(tripid) on delete cascade,
    vehicle_id uuid not null references public.vehicles(vin),
    driver_id uuid not null references public.drivers(driverid),
    type text not null check (type in ('pre_trip', 'post_trip')),
    status text not null check (status in ('passed', 'failed')),
    odometer_reading double precision,
    fuel_level double precision,
    notes text,
    created_at timestamptz not null default now()
);

create table if not exists public.inspection_items (
    id uuid primary key default gen_random_uuid(),
    inspection_id uuid not null references public.vehicle_inspections(id) on delete cascade,
    item_name text not null,
    status text not null check (status in ('pass', 'fail')),
    fail_description text,
    fail_photo_url text,
    created_at timestamptz not null default now()
);
