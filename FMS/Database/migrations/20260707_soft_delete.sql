alter table public.users
    add column if not exists deleted_at timestamptz;

alter table public.vehicles
    add column if not exists deleted_at timestamptz;
