-- Clean demo data for the fleet-manager workflow screens.
-- Run this from the Supabase SQL editor or any SQL client with admin privileges.
-- If public.users.userid references auth.users.id in your Supabase project,
-- create matching auth users first or adapt these UUIDs to existing auth IDs.

begin;

alter table public.users
    add column if not exists avatarurl text,
    add column if not exists first_time_login boolean default true;

alter table public.maintenance_task
    add column if not exists title text,
    add column if not exists reporteddate timestamptz default now(),
    add column if not exists completedat timestamptz,
    add column if not exists timetakenhours numeric(8, 2),
    add column if not exists partssummary text,
    add column if not exists totalcost numeric(12, 2),
    add column if not exists photourls text[] default '{}';

create temporary table cleanup_bad_users on commit drop as
select userid
from public.users
where lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
        'anonymous user',
        'anon user',
        'demo user',
        'sample user',
        'test user',
        'unknown user',
        'veer driver'
    )
    or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
    or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
    or email ilike any (array[
        'anonymous%',
        'anon%',
        'test%',
        'demo.user%',
        'sample%',
        'placeholder%'
    ]);

create temporary table cleanup_bad_drivers on commit drop as
select driverid
from public.drivers
where userid in (select userid from cleanup_bad_users);

create temporary table cleanup_bad_personnel on commit drop as
select personnelid
from public.maintenance_personnel
where userid in (select userid from cleanup_bad_users);

create temporary table cleanup_bad_managers on commit drop as
select managerid
from public.fleet_manager
where userid in (select userid from cleanup_bad_users);

create temporary table cleanup_bad_vehicles on commit drop as
select vin
from public.vehicles
where regexp_replace(licence_plate, '[[:space:]]+', '', 'g') in ('UK071234', 'UK07AJ9125', 'UL043456')
    or lower(coalesce(make, '') || ' ' || coalesce(model, '')) ilike any (array[
        '%that%lead%',
        '%saw safe%',
        '%mercedes abcd%'
    ])
    or lower(coalesce(make, '')) in ('that’s', 'thats', 'that''s', 'saw')
    or lower(coalesce(model, '')) in ('lead', 'safe', 'abcd');

create temporary table cleanup_bad_tasks on commit drop as
select taskid
from public.maintenance_task
where coalesce(title, '') ilike any (array[
        'preventive%',
        '%preventive maintenance%',
        '%preventive measure%'
    ])
    or lower(coalesce(description, '')) = 'routine service inspection and repair request.'
    or executedby in (select personnelid from cleanup_bad_personnel)
    or scheduledby in (select managerid from cleanup_bad_managers)
    or taskid in (
        select taskid
        from public.task_vehicles
        where vin in (select vin from cleanup_bad_vehicles)
    );

delete from public.maintenance_task_parts
where taskid in (select taskid from cleanup_bad_tasks);

delete from public.task_vehicles
where taskid in (select taskid from cleanup_bad_tasks)
    or vin in (select vin from cleanup_bad_vehicles);

delete from public.maintenance_task
where taskid in (select taskid from cleanup_bad_tasks);

delete from public.trips
where vehicleid in (select vin from cleanup_bad_vehicles)
    or driverid in (select driverid from cleanup_bad_drivers)
    or lower(startlocation) in ('dun', 'blr')
    or lower(endlocation) in ('dun', 'blr');

update public.vehicles
set driverid = null
where driverid in (select driverid from cleanup_bad_drivers);

delete from public.vehicles
where vin in (select vin from cleanup_bad_vehicles);

delete from public.drivers
where driverid in (select driverid from cleanup_bad_drivers);

delete from public.maintenance_personnel
where personnelid in (select personnelid from cleanup_bad_personnel);

delete from public.fleet_manager
where managerid in (select managerid from cleanup_bad_managers);

delete from public.users
where userid in (select userid from cleanup_bad_users);

insert into public.users (userid, email, aadhar, contact, role, f_name, l_name, address, isactive, createdat, avatarurl, first_time_login)
values
    ('10000000-0000-0000-0000-000000000001', 'kavya.manager@fms.local', '111122223333', 9000000001, 'fleet_manager', 'Kavya', 'Rao', 'Fleet HQ, Sector 44, Gurugram', true, '2026-06-24T08:00:00Z', 'https://i.pravatar.cc/240?u=kavya.manager@fms.local', false),
    ('10000000-0000-0000-0000-000000000011', 'rohan.driver@fms.local', '222233334444', 9000000011, 'driver', 'Rohan', 'Sharma', 'Sector 22, Noida', true, '2026-06-25T08:00:00Z', 'https://i.pravatar.cc/240?u=rohan.driver@fms.local', false),
    ('10000000-0000-0000-0000-000000000012', 'meera.driver@fms.local', '333344445555', 9000000012, 'driver', 'Meera', 'Joshi', 'Dwarka, New Delhi', true, '2026-06-25T08:30:00Z', 'https://i.pravatar.cc/240?u=meera.driver@fms.local', false),
    ('10000000-0000-0000-0000-000000000013', 'arjun.driver@fms.local', '333344446666', 9000000013, 'driver', 'Arjun', 'Rawat', 'Rajpur Road, Dehradun', true, '2026-06-25T09:00:00Z', 'https://i.pravatar.cc/240?u=arjun.driver@fms.local', false),
    ('10000000-0000-0000-0000-000000000021', 'suresh.service@fms.local', '444455556666', 9000000021, 'maintenance_personnel', 'Suresh', 'Yadav', 'Workshop Bay 1, Gurugram', true, '2026-06-25T09:30:00Z', 'https://i.pravatar.cc/240?u=suresh.service@fms.local', false),
    ('10000000-0000-0000-0000-000000000022', 'nisha.service@fms.local', '555566667777', 9000000022, 'maintenance_personnel', 'Nisha', 'Kapoor', 'Workshop Bay 2, Gurugram', true, '2026-06-25T10:00:00Z', 'https://i.pravatar.cc/240?u=nisha.service@fms.local', false)
on conflict (userid) do update set
    email = excluded.email,
    aadhar = excluded.aadhar,
    contact = excluded.contact,
    role = excluded.role,
    f_name = excluded.f_name,
    l_name = excluded.l_name,
    address = excluded.address,
    isactive = excluded.isactive,
    avatarurl = excluded.avatarurl,
    first_time_login = excluded.first_time_login;

insert into public.fleet_manager (managerid, userid)
values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001')
on conflict (managerid) do update set
    userid = excluded.userid;

insert into public.drivers (driverid, licencenum, vehicletype, status, userid)
values
    ('30000000-0000-0000-0000-000000000011', 'DL-042026-7788', 'truck', 'active', '10000000-0000-0000-0000-000000000011'),
    ('30000000-0000-0000-0000-000000000012', 'DL-032026-1144', 'van', 'active', '10000000-0000-0000-0000-000000000012'),
    ('30000000-0000-0000-0000-000000000013', 'DL-052026-9042', 'bus', 'active', '10000000-0000-0000-0000-000000000013')
on conflict (driverid) do update set
    licencenum = excluded.licencenum,
    vehicletype = excluded.vehicletype,
    status = excluded.status,
    userid = excluded.userid;

insert into public.maintenance_personnel (personnelid, status, userid)
values
    ('40000000-0000-0000-0000-000000000021', 'active', '10000000-0000-0000-0000-000000000021'),
    ('40000000-0000-0000-0000-000000000022', 'active', '10000000-0000-0000-0000-000000000022')
on conflict (personnelid) do update set
    status = excluded.status,
    userid = excluded.userid;

insert into public.vehicles (vin, make, model, year, licence_plate, status, vehicletype, driverid)
values
    ('50000000-0000-0000-0000-000000000001', 'Tata', 'Prima 3530.K', 2023, 'HR55AB1234', 'active', 'truck', '30000000-0000-0000-0000-000000000011'),
    ('50000000-0000-0000-0000-000000000002', 'Mahindra', 'Supro Cargo VX', 2022, 'DL01CD6789', 'active', 'van', '30000000-0000-0000-0000-000000000012'),
    ('50000000-0000-0000-0000-000000000003', 'Force', 'Traveller 3350', 2024, 'UK07PA2468', 'maintenance', 'bus', '30000000-0000-0000-0000-000000000013'),
    ('50000000-0000-0000-0000-000000000004', 'Maruti Suzuki', 'Ertiga Tour M', 2024, 'HR38KT9090', 'inactive', 'car', null)
on conflict (vin) do update set
    make = excluded.make,
    model = excluded.model,
    year = excluded.year,
    licence_plate = excluded.licence_plate,
    status = excluded.status,
    vehicletype = excluded.vehicletype,
    driverid = excluded.driverid;

insert into public.trips (tripid, startlocation, endlocation, starttime, endtime, vehicleid, driverid, status, rejection_reason)
values
    ('60000000-0000-0000-0000-000000000001', 'Gurugram Logistics Hub', 'Jaipur Warehouse', '2026-07-01T03:30:00Z', null, '50000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000011', 'in_progress', null),
    ('60000000-0000-0000-0000-000000000002', 'Delhi Central Depot', 'Chandigarh Retail Store', '2026-07-02T02:00:00Z', null, '50000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000012', 'pending', null),
    ('60000000-0000-0000-0000-000000000003', 'Dehradun Bus Terminal', 'Haridwar Depot', '2026-06-30T04:00:00Z', '2026-06-30T07:40:00Z', '50000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000013', 'completed', null),
    ('60000000-0000-0000-0000-000000000004', 'Noida Depot', 'Agra Distribution Center', '2026-07-01T07:15:00Z', null, '50000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000012', 'accepted', null)
on conflict (tripid) do update set
    startlocation = excluded.startlocation,
    endlocation = excluded.endlocation,
    starttime = excluded.starttime,
    endtime = excluded.endtime,
    vehicleid = excluded.vehicleid,
    driverid = excluded.driverid,
    status = excluded.status,
    rejection_reason = excluded.rejection_reason;

insert into public.maintenance_task (taskid, title, description, scheduleddate, isurgent, scheduledby, executedby, status, reporteddate, completedat, timetakenhours, partssummary, totalcost, photourls)
values
    ('70000000-0000-0000-0000-000000000001', 'Brake pad inspection', 'Front brake squeal reported during Dehradun route check.', '2026-07-01', true, '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000021', 'in_progress', '2026-07-01T05:15:00Z', null, null, null, null, array['https://images.unsplash.com/photo-1486262715619-67b85e0b08d3?w=900&q=80']),
    ('70000000-0000-0000-0000-000000000002', 'Engine oil and filter change', 'Replace engine oil, oil filter, and inspect for leakage before next highway assignment.', '2026-07-01', false, '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000022', 'assigned', '2026-07-01T04:45:00Z', null, null, null, null, '{}'),
    ('70000000-0000-0000-0000-000000000003', 'Rear tyre replacement', 'Rear tyre pair replaced after tread-depth inspection.', '2026-06-30', false, '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000021', 'completed', '2026-06-30T03:30:00Z', '2026-06-30T06:15:00Z', 2.75, '2 rear tyres, valve set', 24500.00, array['https://images.unsplash.com/photo-1525609004556-c46c7d6cf023?w=900&q=80']),
    ('70000000-0000-0000-0000-000000000004', 'Battery health check', 'Vehicle has been inactive; test battery voltage and charging system.', '2026-07-03', false, '20000000-0000-0000-0000-000000000001', null, 'scheduled', '2026-07-01T06:20:00Z', null, null, null, null, '{}')
on conflict (taskid) do update set
    title = excluded.title,
    description = excluded.description,
    scheduleddate = excluded.scheduleddate,
    isurgent = excluded.isurgent,
    scheduledby = excluded.scheduledby,
    executedby = excluded.executedby,
    status = excluded.status,
    reporteddate = excluded.reporteddate,
    completedat = excluded.completedat,
    timetakenhours = excluded.timetakenhours,
    partssummary = excluded.partssummary,
    totalcost = excluded.totalcost,
    photourls = excluded.photourls;

insert into public.task_vehicles (taskid, vin)
values
    ('70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003'),
    ('70000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001'),
    ('70000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000002'),
    ('70000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000004')
on conflict (taskid, vin) do nothing;

insert into public.inventory (partid, partname, cost, quantity, vehicletype)
values
    ('80000000-0000-0000-0000-000000000001', 'Rear tyre', 12000.00, 12, 'truck'),
    ('80000000-0000-0000-0000-000000000002', 'Valve set', 500.00, 30, 'truck'),
    ('80000000-0000-0000-0000-000000000003', 'Brake pad set', 4200.00, 10, 'bus'),
    ('80000000-0000-0000-0000-000000000004', 'Engine oil 15W-40', 1850.00, 24, 'truck'),
    ('80000000-0000-0000-0000-000000000005', 'Oil filter', 950.00, 18, 'truck'),
    ('80000000-0000-0000-0000-000000000006', 'Battery 12V', 6800.00, 6, 'car')
on conflict (partid) do update set
    partname = excluded.partname,
    cost = excluded.cost,
    quantity = excluded.quantity,
    vehicletype = excluded.vehicletype;

insert into public.maintenance_task_parts (taskid, partid, quantityused)
values
    ('70000000-0000-0000-0000-000000000003', '80000000-0000-0000-0000-000000000001', 2),
    ('70000000-0000-0000-0000-000000000003', '80000000-0000-0000-0000-000000000002', 1)
on conflict (taskid, partid) do update set
    quantityused = excluded.quantityused;

commit;
