-- Normalize existing fuel_type values to lowercase
update public.vehicles set fuel_type = lower(fuel_type) where fuel_type is not null and fuel_type != lower(fuel_type);

-- Restrict vehicle fuel types to petrol, diesel, cng
alter table public.vehicles
    add constraint vehicles_fuel_type_check
        check (fuel_type is null or fuel_type in ('petrol', 'diesel', 'cng'));
