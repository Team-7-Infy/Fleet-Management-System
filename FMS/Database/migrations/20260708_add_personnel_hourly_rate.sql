-- Add hourly_rate to maintenance_personnel table
alter table public.maintenance_personnel
    add column if not exists hourly_rate numeric(10, 2) not null default 500.00;

comment on column public.maintenance_personnel.hourly_rate is 'Hourly rate of the maintenance personnel used to calculate labor cost.';
