alter table public.vehicles
    add column if not exists maintenance_km_interval integer,
    add column if not exists maintenance_month_interval integer;
