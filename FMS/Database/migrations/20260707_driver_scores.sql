create table if not exists public.driver_scores (
    id uuid primary key default gen_random_uuid(),
    driver_id uuid not null references public.drivers(driverid) on delete cascade,
    overall_score numeric(5, 2) not null default 0,
    inspection_false_rate numeric(5, 2) default 0,
    geofence_violation_rate numeric(5, 2) default 0,
    compliance_violation_rate numeric(5, 2) default 0,
    mileage_accuracy numeric(5, 2) default 0,
    calculated_at timestamptz not null default now(),
    unique(driver_id)
);
