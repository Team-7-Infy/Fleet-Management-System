alter table public.vehicles
    drop constraint if exists vehicles_status_check;

alter table public.vehicles
    add constraint vehicles_status_check
        check (status in ('available', 'assigned', 'in_maintenance', 'out_of_service'));

update public.vehicles set status = 'available' where status = 'active';
update public.vehicles set status = 'in_maintenance' where status = 'maintenance';
