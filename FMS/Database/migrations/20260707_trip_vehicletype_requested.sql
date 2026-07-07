alter table public.trips
    add column if not exists vehicletype_requested text;
