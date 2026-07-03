alter table public.trips
add column if not exists updated_at timestamptz not null default now();

create or replace function public.set_trips_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists trg_set_trips_updated_at on public.trips;

create trigger trg_set_trips_updated_at
before update on public.trips
for each row
execute function public.set_trips_updated_at();

comment on column public.trips.status is
'Manager trip lifecycle events for driver realtime listeners: scheduled on insert, cancelled on manager cancellation, accepted/in_progress/completed from driver flow.';
