-- Allow unassigned trips (no vehicle yet)
alter table public.trips alter column vehicleid drop not null;
