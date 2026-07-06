create table if not exists public.driver_schedules (
    id uuid primary key default gen_random_uuid(),
    driver_id uuid not null references public.drivers(driverid) on delete cascade,
    start_time timestamptz not null,
    end_time timestamptz not null,
    is_available boolean not null default true,
    notes text,
    created_at timestamptz not null default now()
);

create index if not exists idx_driver_schedules_driver_time on public.driver_schedules(driver_id, start_time, end_time);
