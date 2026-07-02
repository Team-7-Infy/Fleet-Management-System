-- SQL Editor safe demo seed for Fleet Manager screens.
-- No temporary tables are used. Paste the entire script into Supabase SQL Editor
-- and run it as one query.

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

alter table public.maintenance_task_parts
    add column if not exists quantityused integer,
    add column if not exists quantity integer,
    add column if not exists unit_price numeric(12, 2);

delete from public.maintenance_task_parts
where taskid::text like '70000000-%'
   or taskid::text like '71000000-%'
   or partid::text like '80000000-%'
   or partid::text like '81000000-%'
   or taskid in (
        select taskid
        from public.maintenance_task
        where coalesce(title, '') ilike any (array['preventive%', '%preventive maintenance%', '%preventive measure%'])
           or lower(coalesce(description, '')) = 'routine service inspection and repair request.'
   );

delete from public.task_vehicles
where taskid::text like '70000000-%'
   or taskid::text like '71000000-%'
   or vin::text like '50000000-%'
   or vin::text like '51000000-%'
   or vin in (
        select vin
        from public.vehicles
        where regexp_replace(licence_plate, '[[:space:]]+', '', 'g') in (
            'UK071234', 'UK07AJ9125', 'UL043456',
            'HR55AB1234', 'DL01CD6789', 'UK07PA2468', 'HR38KT9090',
            'RJ14TR5521', 'UP16VT9832', 'CH01BU4412', 'HR26CR8841',
            'PB10FT7290', 'UP32VX1208', 'DL12UB5500', 'DL05CA9091'
        )
   );

delete from public.maintenance_task
where taskid::text like '70000000-%'
   or taskid::text like '71000000-%'
   or coalesce(title, '') ilike any (array['preventive%', '%preventive maintenance%', '%preventive measure%'])
   or lower(coalesce(description, '')) = 'routine service inspection and repair request.'
   or executedby::text like '40000000-%'
   or executedby::text like '41000000-%'
   or executedby in (
        select personnelid
        from public.maintenance_personnel
        where userid in (
            select userid
            from public.users
            where lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
                    'anonymous user', 'anon user', 'demo user', 'sample user',
                    'test user', 'unknown user', 'veer driver'
                )
               or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
               or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
               or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local'])
        )
   )
   or scheduledby::text like '20000000-%'
   or scheduledby::text like '21000000-%'
   or scheduledby in (
        select managerid
        from public.fleet_manager
        where userid in (
            select userid
            from public.users
            where lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
                    'anonymous user', 'anon user', 'demo user', 'sample user',
                    'test user', 'unknown user', 'veer driver'
                )
               or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
               or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
               or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local'])
        )
   );

do $$
begin
    if to_regclass('public.route_waypoints') is not null then
        delete from public.route_waypoints
        where tripid::text like '60000000-%'
           or tripid::text like '61000000-%'
           or tripid in (
                select tripid
                from public.trips
	                where vehicleid::text like '50000000-%'
	                   or vehicleid::text like '51000000-%'
	                   or vehicleid in (
	                        select vin
	                        from public.vehicles
	                        where regexp_replace(licence_plate, '[[:space:]]+', '', 'g') in (
	                            'UK071234', 'UK07AJ9125', 'UL043456',
	                            'HR55AB1234', 'DL01CD6789', 'UK07PA2468', 'HR38KT9090',
	                            'RJ14TR5521', 'UP16VT9832', 'CH01BU4412', 'HR26CR8841',
	                            'PB10FT7290', 'UP32VX1208', 'DL12UB5500', 'DL05CA9091'
	                        )
	                           or lower(coalesce(make, '') || ' ' || coalesce(model, '')) ilike any (array[
	                                '%that%lead%', '%saw safe%', '%mercedes abcd%'
	                           ])
	                           or lower(coalesce(make, '')) in ('thats', 'that''s', 'saw')
	                           or lower(coalesce(model, '')) in ('lead', 'safe', 'abcd')
	                   )
	                   or driverid::text like '30000000-%'
	                   or driverid::text like '31000000-%'
	                   or driverid in (
	                        select driverid
	                        from public.drivers
	                        where userid in (
	                            select userid
	                            from public.users
	                            where userid::text like '10000000-%'
	                               or userid::text like '11000000-%'
	                               or lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
	                                    'anonymous user', 'anon user', 'demo user', 'sample user',
	                                    'test user', 'unknown user', 'veer driver'
	                               )
	                               or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
	                               or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
	                               or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local'])
	                        )
	                   )
                   or lower(startlocation) in ('dun', 'blr')
                   or lower(endlocation) in ('dun', 'blr')
           );
    end if;

    if to_regclass('public.deviation_alert') is not null then
        delete from public.deviation_alert
	        where tripid::text like '60000000-%'
	           or tripid::text like '61000000-%'
	           or vehicleid::text like '50000000-%'
	           or vehicleid::text like '51000000-%'
	           or vehicleid in (
	                select vin
	                from public.vehicles
	                where regexp_replace(licence_plate, '[[:space:]]+', '', 'g') in (
	                    'UK071234', 'UK07AJ9125', 'UL043456',
	                    'HR55AB1234', 'DL01CD6789', 'UK07PA2468', 'HR38KT9090',
	                    'RJ14TR5521', 'UP16VT9832', 'CH01BU4412', 'HR26CR8841',
	                    'PB10FT7290', 'UP32VX1208', 'DL12UB5500', 'DL05CA9091'
	                )
	                   or lower(coalesce(make, '') || ' ' || coalesce(model, '')) ilike any (array[
	                        '%that%lead%', '%saw safe%', '%mercedes abcd%'
	                   ])
	                   or lower(coalesce(make, '')) in ('thats', 'that''s', 'saw')
	                   or lower(coalesce(model, '')) in ('lead', 'safe', 'abcd')
	           );
    end if;

    if to_regclass('public.geofence') is not null then
        delete from public.geofence
        where tripid::text like '60000000-%'
           or tripid::text like '61000000-%'
           or tripid in (
                select tripid
                from public.trips
	                where vehicleid::text like '50000000-%'
	                   or vehicleid::text like '51000000-%'
	                   or vehicleid in (
	                        select vin
	                        from public.vehicles
	                        where regexp_replace(licence_plate, '[[:space:]]+', '', 'g') in (
	                            'UK071234', 'UK07AJ9125', 'UL043456',
	                            'HR55AB1234', 'DL01CD6789', 'UK07PA2468', 'HR38KT9090',
	                            'RJ14TR5521', 'UP16VT9832', 'CH01BU4412', 'HR26CR8841',
	                            'PB10FT7290', 'UP32VX1208', 'DL12UB5500', 'DL05CA9091'
	                        )
	                           or lower(coalesce(make, '') || ' ' || coalesce(model, '')) ilike any (array[
	                                '%that%lead%', '%saw safe%', '%mercedes abcd%'
	                           ])
	                           or lower(coalesce(make, '')) in ('thats', 'that''s', 'saw')
	                           or lower(coalesce(model, '')) in ('lead', 'safe', 'abcd')
	                   )
	                   or driverid::text like '30000000-%'
	                   or driverid::text like '31000000-%'
	                   or driverid in (
	                        select driverid
	                        from public.drivers
	                        where userid in (
	                            select userid
	                            from public.users
	                            where userid::text like '10000000-%'
	                               or userid::text like '11000000-%'
	                               or lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
	                                    'anonymous user', 'anon user', 'demo user', 'sample user',
	                                    'test user', 'unknown user', 'veer driver'
	                               )
	                               or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
	                               or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
	                               or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local'])
	                        )
	                   )
                   or lower(startlocation) in ('dun', 'blr')
                   or lower(endlocation) in ('dun', 'blr')
           );
    end if;

    if to_regclass('public.telemetry_log') is not null then
        delete from public.telemetry_log
        where driverid::text like '30000000-%'
           or driverid::text like '31000000-%'
           or driverid in (
                select driverid
                from public.drivers
                where userid::text like '10000000-%'
                   or userid::text like '11000000-%'
                   or userid in (
                        select userid
                        from public.users
                        where lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
                                'anonymous user', 'anon user', 'demo user', 'sample user',
                                'test user', 'unknown user', 'veer driver'
                            )
                           or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
                           or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
                           or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local'])
                   )
           );
    end if;
end $$;

delete from public.trips
where tripid::text like '60000000-%'
   or tripid::text like '61000000-%'
   or vehicleid::text like '50000000-%'
   or vehicleid::text like '51000000-%'
   or vehicleid in (
        select vin
        from public.vehicles
        where regexp_replace(licence_plate, '[[:space:]]+', '', 'g') in (
            'UK071234', 'UK07AJ9125', 'UL043456',
            'HR55AB1234', 'DL01CD6789', 'UK07PA2468', 'HR38KT9090',
            'RJ14TR5521', 'UP16VT9832', 'CH01BU4412', 'HR26CR8841',
            'PB10FT7290', 'UP32VX1208', 'DL12UB5500', 'DL05CA9091'
        )
           or lower(coalesce(make, '') || ' ' || coalesce(model, '')) ilike any (array[
                '%that%lead%', '%saw safe%', '%mercedes abcd%'
           ])
           or lower(coalesce(make, '')) in ('thats', 'that''s', 'saw')
           or lower(coalesce(model, '')) in ('lead', 'safe', 'abcd')
   )
   or driverid::text like '30000000-%'
   or driverid::text like '31000000-%'
   or driverid in (
        select driverid
        from public.drivers
        where userid in (
            select userid
            from public.users
            where userid::text like '10000000-%'
               or userid::text like '11000000-%'
               or lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
                    'anonymous user', 'anon user', 'demo user', 'sample user',
                    'test user', 'unknown user', 'veer driver'
               )
               or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
               or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
               or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local'])
        )
   )
   or lower(startlocation) in ('dun', 'blr')
   or lower(endlocation) in ('dun', 'blr');

update public.vehicles
set driverid = null
where driverid::text like '30000000-%'
   or driverid::text like '31000000-%'
   or driverid in (
        select driverid
        from public.drivers
        where userid in (
            select userid
            from public.users
            where userid::text like '10000000-%'
               or userid::text like '11000000-%'
               or lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
                    'anonymous user', 'anon user', 'demo user', 'sample user',
                    'test user', 'unknown user', 'veer driver'
               )
               or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
               or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
               or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local'])
        )
   );

delete from public.vehicles
where vin::text like '50000000-%'
   or vin::text like '51000000-%'
   or regexp_replace(licence_plate, '[[:space:]]+', '', 'g') in (
        'UK071234', 'UK07AJ9125', 'UL043456',
        'HR55AB1234', 'DL01CD6789', 'UK07PA2468', 'HR38KT9090',
        'RJ14TR5521', 'UP16VT9832', 'CH01BU4412', 'HR26CR8841',
        'PB10FT7290', 'UP32VX1208', 'DL12UB5500', 'DL05CA9091'
   )
   or lower(coalesce(make, '') || ' ' || coalesce(model, '')) ilike any (array[
        '%that%lead%', '%saw safe%', '%mercedes abcd%'
   ])
   or lower(coalesce(make, '')) in ('thats', 'that''s', 'saw')
   or lower(coalesce(model, '')) in ('lead', 'safe', 'abcd');

delete from public.inventory
where partid::text like '80000000-%'
   or partid::text like '81000000-%';

delete from public.drivers
where driverid::text like '30000000-%'
   or driverid::text like '31000000-%'
   or userid::text like '10000000-%'
   or userid::text like '11000000-%'
   or userid in (
        select userid
        from public.users
        where lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
                'anonymous user', 'anon user', 'demo user', 'sample user',
                'test user', 'unknown user', 'veer driver'
            )
           or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
           or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
           or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local'])
   );

delete from public.maintenance_personnel
where personnelid::text like '40000000-%'
   or personnelid::text like '41000000-%'
   or userid::text like '10000000-%'
   or userid::text like '11000000-%'
   or userid in (
        select userid
        from public.users
        where lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
                'anonymous user', 'anon user', 'demo user', 'sample user',
                'test user', 'unknown user', 'veer driver'
            )
           or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
           or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
           or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local'])
   );

delete from public.fleet_manager
where managerid::text like '20000000-%'
   or managerid::text like '21000000-%'
   or userid::text like '10000000-%'
   or userid::text like '11000000-%'
   or userid in (
        select userid
        from public.users
        where lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
                'anonymous user', 'anon user', 'demo user', 'sample user',
                'test user', 'unknown user', 'veer driver'
            )
           or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
           or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
           or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local'])
   );

delete from public.users
where userid::text like '10000000-%'
   or userid::text like '11000000-%'
   or lower(trim(coalesce(f_name, '') || ' ' || coalesce(l_name, ''))) in (
        'anonymous user', 'anon user', 'demo user', 'sample user',
        'test user', 'unknown user', 'veer driver'
   )
   or lower(coalesce(f_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown')
   or lower(coalesce(l_name, '')) in ('anonymous', 'anon', 'demo', 'sample', 'test', 'unknown', 'driver', 'lead')
   or email ilike any (array['anonymous%', 'anon%', 'test%', 'demo.user%', 'sample%', 'placeholder%', '%@fms.local']);

insert into public.users (userid, email, aadhar, contact, role, f_name, l_name, address, isactive, createdat, avatarurl, first_time_login)
values
    ('11000000-0000-0000-0000-000000000001', 'kavya.manager@fms.local', '111122223333', 9100000001, 'fleet_manager', 'Kavya', 'Rao', 'Fleet HQ, Sector 44, Gurugram', true, '2026-06-20T08:00:00Z', 'https://i.pravatar.cc/240?u=kavya.manager@fms.local', false),
    ('11000000-0000-0000-0000-000000000101', 'rohan.sharma@fms.local', '222233330101', 9100000101, 'driver', 'Rohan', 'Sharma', 'Sector 22, Noida', true, '2026-06-21T08:00:00Z', 'https://i.pravatar.cc/240?u=rohan.sharma@fms.local', false),
    ('11000000-0000-0000-0000-000000000102', 'meera.joshi@fms.local', '222233330102', 9100000102, 'driver', 'Meera', 'Joshi', 'Dwarka, New Delhi', true, '2026-06-21T08:15:00Z', 'https://i.pravatar.cc/240?u=meera.joshi@fms.local', false),
    ('11000000-0000-0000-0000-000000000103', 'arjun.rawat@fms.local', '222233330103', 9100000103, 'driver', 'Arjun', 'Rawat', 'Rajpur Road, Dehradun', true, '2026-06-21T08:30:00Z', 'https://i.pravatar.cc/240?u=arjun.rawat@fms.local', false),
    ('11000000-0000-0000-0000-000000000104', 'farhan.ali@fms.local', '222233330104', 9100000104, 'driver', 'Farhan', 'Ali', 'Jamia Nagar, New Delhi', true, '2026-06-21T08:45:00Z', 'https://i.pravatar.cc/240?u=farhan.ali@fms.local', false),
    ('11000000-0000-0000-0000-000000000105', 'isha.bansal@fms.local', '222233330105', 9100000105, 'driver', 'Isha', 'Bansal', 'Civil Lines, Jaipur', true, '2026-06-21T09:00:00Z', 'https://i.pravatar.cc/240?u=isha.bansal@fms.local', false),
    ('11000000-0000-0000-0000-000000000106', 'manav.singh@fms.local', '222233330106', 9100000106, 'driver', 'Manav', 'Singh', 'Model Town, Panipat', true, '2026-06-21T09:15:00Z', 'https://i.pravatar.cc/240?u=manav.singh@fms.local', false),
    ('11000000-0000-0000-0000-000000000107', 'naina.kapoor@fms.local', '222233330107', 9100000107, 'driver', 'Naina', 'Kapoor', 'Vasant Kunj, New Delhi', true, '2026-06-21T09:30:00Z', 'https://i.pravatar.cc/240?u=naina.kapoor@fms.local', false),
    ('11000000-0000-0000-0000-000000000108', 'dev.malik@fms.local', '222233330108', 9100000108, 'driver', 'Dev', 'Malik', 'Sohna Road, Gurugram', true, '2026-06-21T09:45:00Z', 'https://i.pravatar.cc/240?u=dev.malik@fms.local', false),
    ('11000000-0000-0000-0000-000000000109', 'pranav.sethi@fms.local', '222233330109', 9100000109, 'driver', 'Pranav', 'Sethi', 'Vaishali, Ghaziabad', true, '2026-06-21T10:00:00Z', 'https://i.pravatar.cc/240?u=pranav.sethi@fms.local', false),
    ('11000000-0000-0000-0000-000000000110', 'tara.nair@fms.local', '222233330110', 9100000110, 'driver', 'Tara', 'Nair', 'Indirapuram, Ghaziabad', true, '2026-06-21T10:15:00Z', 'https://i.pravatar.cc/240?u=tara.nair@fms.local', false),
    ('11000000-0000-0000-0000-000000000111', 'kabir.gill@fms.local', '222233330111', 9100000111, 'driver', 'Kabir', 'Gill', 'Phase 7, Mohali', true, '2026-06-21T10:30:00Z', 'https://i.pravatar.cc/240?u=kabir.gill@fms.local', false),
    ('11000000-0000-0000-0000-000000000112', 'zoya.khan@fms.local', '222233330112', 9100000112, 'driver', 'Zoya', 'Khan', 'Alambagh, Lucknow', true, '2026-06-21T10:45:00Z', 'https://i.pravatar.cc/240?u=zoya.khan@fms.local', false),
    ('11000000-0000-0000-0000-000000000201', 'suresh.yadav@fms.local', '444455550201', 9100000201, 'maintenance_personnel', 'Suresh', 'Yadav', 'Workshop Bay 1, Gurugram', true, '2026-06-22T08:00:00Z', 'https://i.pravatar.cc/240?u=suresh.yadav@fms.local', false),
    ('11000000-0000-0000-0000-000000000202', 'nisha.kapoor@fms.local', '444455550202', 9100000202, 'maintenance_personnel', 'Nisha', 'Kapoor', 'Workshop Bay 2, Gurugram', true, '2026-06-22T08:15:00Z', 'https://i.pravatar.cc/240?u=nisha.kapoor@fms.local', false),
    ('11000000-0000-0000-0000-000000000203', 'amit.verma@fms.local', '444455550203', 9100000203, 'maintenance_personnel', 'Amit', 'Verma', 'Workshop Bay 3, Noida', true, '2026-06-22T08:30:00Z', 'https://i.pravatar.cc/240?u=amit.verma@fms.local', false),
    ('11000000-0000-0000-0000-000000000204', 'pooja.menon@fms.local', '444455550204', 9100000204, 'maintenance_personnel', 'Pooja', 'Menon', 'Parts Desk, Gurugram', true, '2026-06-22T08:45:00Z', 'https://i.pravatar.cc/240?u=pooja.menon@fms.local', false),
    ('11000000-0000-0000-0000-000000000205', 'rakesh.pal@fms.local', '444455550205', 9100000205, 'maintenance_personnel', 'Rakesh', 'Pal', 'Paint Shop, Faridabad', true, '2026-06-22T09:00:00Z', 'https://i.pravatar.cc/240?u=rakesh.pal@fms.local', false),
    ('11000000-0000-0000-0000-000000000206', 'fatima.sheikh@fms.local', '444455550206', 9100000206, 'maintenance_personnel', 'Fatima', 'Sheikh', 'Electrical Bay, Delhi', true, '2026-06-22T09:15:00Z', 'https://i.pravatar.cc/240?u=fatima.sheikh@fms.local', false),
    ('11000000-0000-0000-0000-000000000207', 'harish.nautiyal@fms.local', '444455550207', 9100000207, 'maintenance_personnel', 'Harish', 'Nautiyal', 'Service Bay, Dehradun', true, '2026-06-22T09:30:00Z', 'https://i.pravatar.cc/240?u=harish.nautiyal@fms.local', false),
    ('11000000-0000-0000-0000-000000000208', 'komal.arora@fms.local', '444455550208', 9100000208, 'maintenance_personnel', 'Komal', 'Arora', 'Workshop Bay 4, Jaipur', true, '2026-06-22T09:45:00Z', 'https://i.pravatar.cc/240?u=komal.arora@fms.local', false),
    ('11000000-0000-0000-0000-000000000209', 'vikram.rao@fms.local', '444455550209', 9100000209, 'maintenance_personnel', 'Vikram', 'Rao', 'Body Shop, Gurugram', true, '2026-06-22T10:00:00Z', 'https://i.pravatar.cc/240?u=vikram.rao@fms.local', false),
    ('11000000-0000-0000-0000-000000000210', 'anjali.das@fms.local', '444455550210', 9100000210, 'maintenance_personnel', 'Anjali', 'Das', 'Inspection Bay, Noida', true, '2026-06-22T10:15:00Z', 'https://i.pravatar.cc/240?u=anjali.das@fms.local', false),
    ('11000000-0000-0000-0000-000000000211', 'chetan.kulkarni@fms.local', '444455550211', 9100000211, 'maintenance_personnel', 'Chetan', 'Kulkarni', 'Tyre Bay, Delhi', true, '2026-06-22T10:30:00Z', 'https://i.pravatar.cc/240?u=chetan.kulkarni@fms.local', false),
    ('11000000-0000-0000-0000-000000000212', 'leena.thomas@fms.local', '444455550212', 9100000212, 'maintenance_personnel', 'Leena', 'Thomas', 'QA Desk, Gurugram', true, '2026-06-22T10:45:00Z', 'https://i.pravatar.cc/240?u=leena.thomas@fms.local', false);

insert into public.fleet_manager (managerid, userid)
values ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001');

insert into public.drivers (driverid, licencenum, vehicletype, status, userid)
values
    ('31000000-0000-0000-0000-000000000101', 'DL-042026-7101', 'truck', 'active', '11000000-0000-0000-0000-000000000101'),
    ('31000000-0000-0000-0000-000000000102', 'DL-032026-7102', 'van', 'active', '11000000-0000-0000-0000-000000000102'),
    ('31000000-0000-0000-0000-000000000103', 'DL-052026-7103', 'bus', 'active', '11000000-0000-0000-0000-000000000103'),
    ('31000000-0000-0000-0000-000000000104', 'DL-062026-7104', 'car', 'active', '11000000-0000-0000-0000-000000000104'),
    ('31000000-0000-0000-0000-000000000105', 'DL-072026-7105', 'truck', 'active', '11000000-0000-0000-0000-000000000105'),
    ('31000000-0000-0000-0000-000000000106', 'DL-082026-7106', 'van', 'active', '11000000-0000-0000-0000-000000000106'),
    ('31000000-0000-0000-0000-000000000107', 'DL-092026-7107', 'bus', 'active', '11000000-0000-0000-0000-000000000107'),
    ('31000000-0000-0000-0000-000000000108', 'DL-102026-7108', 'car', 'active', '11000000-0000-0000-0000-000000000108'),
    ('31000000-0000-0000-0000-000000000109', 'DL-112026-7109', 'truck', 'active', '11000000-0000-0000-0000-000000000109'),
    ('31000000-0000-0000-0000-000000000110', 'DL-122026-7110', 'van', 'active', '11000000-0000-0000-0000-000000000110'),
    ('31000000-0000-0000-0000-000000000111', 'DL-012026-7111', 'bus', 'inactive', '11000000-0000-0000-0000-000000000111'),
    ('31000000-0000-0000-0000-000000000112', 'DL-022026-7112', 'car', 'active', '11000000-0000-0000-0000-000000000112');

insert into public.maintenance_personnel (personnelid, status, userid)
values
    ('41000000-0000-0000-0000-000000000201', 'active', '11000000-0000-0000-0000-000000000201'),
    ('41000000-0000-0000-0000-000000000202', 'active', '11000000-0000-0000-0000-000000000202'),
    ('41000000-0000-0000-0000-000000000203', 'active', '11000000-0000-0000-0000-000000000203'),
    ('41000000-0000-0000-0000-000000000204', 'active', '11000000-0000-0000-0000-000000000204'),
    ('41000000-0000-0000-0000-000000000205', 'active', '11000000-0000-0000-0000-000000000205'),
    ('41000000-0000-0000-0000-000000000206', 'active', '11000000-0000-0000-0000-000000000206'),
    ('41000000-0000-0000-0000-000000000207', 'active', '11000000-0000-0000-0000-000000000207'),
    ('41000000-0000-0000-0000-000000000208', 'active', '11000000-0000-0000-0000-000000000208'),
    ('41000000-0000-0000-0000-000000000209', 'active', '11000000-0000-0000-0000-000000000209'),
    ('41000000-0000-0000-0000-000000000210', 'active', '11000000-0000-0000-0000-000000000210'),
    ('41000000-0000-0000-0000-000000000211', 'inactive', '11000000-0000-0000-0000-000000000211'),
    ('41000000-0000-0000-0000-000000000212', 'active', '11000000-0000-0000-0000-000000000212');

insert into public.vehicles (vin, make, model, year, licence_plate, status, vehicletype, driverid)
values
    ('51000000-0000-0000-0000-000000000001', 'Tata', 'Prima 3530.K', 2023, 'HR55AB1234', 'active', 'truck', '31000000-0000-0000-0000-000000000101'),
    ('51000000-0000-0000-0000-000000000002', 'Mahindra', 'Supro Cargo VX', 2022, 'DL01CD6789', 'active', 'van', '31000000-0000-0000-0000-000000000102'),
    ('51000000-0000-0000-0000-000000000003', 'Force', 'Traveller 3350', 2024, 'UK07PA2468', 'maintenance', 'bus', '31000000-0000-0000-0000-000000000103'),
    ('51000000-0000-0000-0000-000000000004', 'Maruti Suzuki', 'Ertiga Tour M', 2024, 'HR38KT9090', 'active', 'car', '31000000-0000-0000-0000-000000000104'),
    ('51000000-0000-0000-0000-000000000005', 'Ashok Leyland', 'Bada Dost i4', 2023, 'RJ14TR5521', 'active', 'truck', '31000000-0000-0000-0000-000000000105'),
    ('51000000-0000-0000-0000-000000000006', 'Tata', 'Winger Cargo', 2022, 'UP16VT9832', 'active', 'van', '31000000-0000-0000-0000-000000000106'),
    ('51000000-0000-0000-0000-000000000007', 'Eicher', 'Skyline Pro 3011', 2021, 'CH01BU4412', 'maintenance', 'bus', '31000000-0000-0000-0000-000000000107'),
    ('51000000-0000-0000-0000-000000000008', 'Toyota', 'Innova Crysta', 2022, 'HR26CR8841', 'active', 'car', '31000000-0000-0000-0000-000000000108'),
    ('51000000-0000-0000-0000-000000000009', 'BharatBenz', '1617R', 2024, 'PB10FT7290', 'active', 'truck', '31000000-0000-0000-0000-000000000109'),
    ('51000000-0000-0000-0000-000000000010', 'Mahindra', 'Bolero Maxx Pik-Up', 2023, 'UP32VX1208', 'active', 'van', '31000000-0000-0000-0000-000000000110'),
    ('51000000-0000-0000-0000-000000000011', 'Force', 'Urbania 3615', 2024, 'DL12UB5500', 'inactive', 'bus', null),
    ('51000000-0000-0000-0000-000000000012', 'Hyundai', 'Aura CNG', 2023, 'DL05CA9091', 'active', 'car', '31000000-0000-0000-0000-000000000112');

insert into public.trips (tripid, startlocation, endlocation, starttime, endtime, vehicleid, driverid, status, rejection_reason)
values
    ('61000000-0000-0000-0000-000000000001', 'Gurugram Logistics Hub', 'Jaipur Warehouse', '2026-07-01T03:30:00Z', null, '51000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000101', 'in_progress', null),
    ('61000000-0000-0000-0000-000000000002', 'Delhi Central Depot', 'Chandigarh Retail Store', '2026-07-01T05:00:00Z', null, '51000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000102', 'accepted', null),
    ('61000000-0000-0000-0000-000000000003', 'Dehradun Bus Terminal', 'Haridwar Depot', '2026-06-30T04:00:00Z', '2026-06-30T07:40:00Z', '51000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000103', 'completed', null),
    ('61000000-0000-0000-0000-000000000004', 'Noida Depot', 'Agra Distribution Center', '2026-07-02T02:30:00Z', null, '51000000-0000-0000-0000-000000000004', '31000000-0000-0000-0000-000000000104', 'pending', null),
    ('61000000-0000-0000-0000-000000000005', 'Jaipur Transport Nagar', 'Ajmer Warehouse', '2026-07-02T04:15:00Z', null, '51000000-0000-0000-0000-000000000005', '31000000-0000-0000-0000-000000000105', 'pending', null),
    ('61000000-0000-0000-0000-000000000006', 'Noida Depot', 'Lucknow Fulfillment Center', '2026-07-02T06:00:00Z', null, '51000000-0000-0000-0000-000000000006', '31000000-0000-0000-0000-000000000106', 'rejection_pending', 'Vehicle AC fault reported before departure.'),
    ('61000000-0000-0000-0000-000000000007', 'Chandigarh ISBT', 'Shimla Bus Stand', '2026-06-29T02:00:00Z', '2026-06-29T07:15:00Z', '51000000-0000-0000-0000-000000000007', '31000000-0000-0000-0000-000000000107', 'completed', null),
    ('61000000-0000-0000-0000-000000000008', 'Gurugram HQ', 'Delhi Airport Cargo', '2026-07-01T07:00:00Z', null, '51000000-0000-0000-0000-000000000008', '31000000-0000-0000-0000-000000000108', 'accepted', null),
    ('61000000-0000-0000-0000-000000000009', 'Ludhiana Freight Terminal', 'Ambala Depot', '2026-07-03T02:15:00Z', null, '51000000-0000-0000-0000-000000000009', '31000000-0000-0000-0000-000000000109', 'pending', null),
    ('61000000-0000-0000-0000-000000000010', 'Lucknow Fulfillment Center', 'Kanpur Hub', '2026-06-30T08:00:00Z', '2026-06-30T10:45:00Z', '51000000-0000-0000-0000-000000000010', '31000000-0000-0000-0000-000000000110', 'completed', null),
    ('61000000-0000-0000-0000-000000000011', 'Delhi Central Depot', 'Meerut Retail Store', '2026-07-03T05:45:00Z', null, '51000000-0000-0000-0000-000000000012', '31000000-0000-0000-0000-000000000112', 'pending', null),
    ('61000000-0000-0000-0000-000000000012', 'Gurugram Logistics Hub', 'Faridabad Plant', '2026-06-28T04:30:00Z', '2026-06-28T06:10:00Z', '51000000-0000-0000-0000-000000000008', '31000000-0000-0000-0000-000000000108', 'completed', null);

insert into public.maintenance_task (taskid, title, description, scheduleddate, isurgent, scheduledby, executedby, status, reporteddate, completedat, timetakenhours, partssummary, totalcost, photourls)
values
    ('71000000-0000-0000-0000-000000000001', 'Brake pad inspection', 'Front brake squeal reported during Dehradun route check.', '2026-07-01', true, '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000201', 'in_progress', '2026-07-01T05:15:00Z', null, null, null, null, array['https://images.unsplash.com/photo-1486262715619-67b85e0b08d3?w=900&q=80']),
    ('71000000-0000-0000-0000-000000000002', 'Engine oil and filter change', 'Replace engine oil, oil filter, and inspect for leakage before next highway assignment.', '2026-07-01', false, '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000202', 'assigned', '2026-07-01T04:45:00Z', null, null, null, null, '{}'),
    ('71000000-0000-0000-0000-000000000003', 'Rear tyre replacement', 'Rear tyre pair replaced after tread-depth inspection.', '2026-06-30', false, '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000203', 'completed', '2026-06-30T03:30:00Z', '2026-06-30T06:15:00Z', 2.75, '2 rear tyres, valve set', 24500.00, array['https://images.unsplash.com/photo-1525609004556-c46c7d6cf023?w=900&q=80']),
    ('71000000-0000-0000-0000-000000000004', 'Battery health check', 'Inactive bus requires battery voltage and charging-system test.', '2026-07-03', false, '21000000-0000-0000-0000-000000000001', null, 'scheduled', '2026-07-01T06:20:00Z', null, null, null, null, '{}'),
    ('71000000-0000-0000-0000-000000000005', 'AC compressor diagnosis', 'Driver reported weak cabin cooling before Lucknow departure.', '2026-07-02', true, '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000206', 'assigned', '2026-07-01T07:10:00Z', null, null, null, null, '{}'),
    ('71000000-0000-0000-0000-000000000006', 'Wheel alignment', 'Vehicle pulling left after Jaipur route.', '2026-06-29', false, '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000208', 'completed', '2026-06-29T09:00:00Z', '2026-06-29T10:30:00Z', 1.50, 'Alignment service', 3200.00, '{}'),
    ('71000000-0000-0000-0000-000000000007', 'Coolant leak inspection', 'Inspect radiator hose and coolant reservoir after overnight parking leak.', '2026-07-02', true, '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000207', 'in_progress', '2026-07-01T08:10:00Z', null, null, null, null, '{}'),
    ('71000000-0000-0000-0000-000000000008', 'Headlamp replacement', 'Replace dim left headlamp and verify night-drive visibility.', '2026-07-02', false, '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000210', 'assigned', '2026-07-01T08:35:00Z', null, null, null, null, '{}'),
    ('71000000-0000-0000-0000-000000000009', 'Clutch pedal adjustment', 'Pedal free play above acceptable range during inspection.', '2026-06-28', false, '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000209', 'completed', '2026-06-28T04:30:00Z', '2026-06-28T06:00:00Z', 1.50, 'Clutch cable adjustment', 2100.00, '{}'),
    ('71000000-0000-0000-0000-000000000010', 'Wiper blade replacement', 'Replace worn wiper blades before monsoon routes.', '2026-07-04', false, '21000000-0000-0000-0000-000000000001', null, 'scheduled', '2026-07-01T09:00:00Z', null, null, null, null, '{}'),
    ('71000000-0000-0000-0000-000000000011', 'Suspension noise check', 'Rear suspension knocking over uneven road sections.', '2026-07-02', true, '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000212', 'assigned', '2026-07-01T09:40:00Z', null, null, null, null, '{}'),
    ('71000000-0000-0000-0000-000000000012', 'Fuel line inspection', 'Fuel smell reported near engine bay during pre-trip inspection.', '2026-07-01', true, '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000204', 'in_progress', '2026-07-01T10:05:00Z', null, null, null, null, '{}');

insert into public.task_vehicles (taskid, vin)
values
    ('71000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000003'),
    ('71000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000001'),
    ('71000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000002'),
    ('71000000-0000-0000-0000-000000000004', '51000000-0000-0000-0000-000000000011'),
    ('71000000-0000-0000-0000-000000000005', '51000000-0000-0000-0000-000000000006'),
    ('71000000-0000-0000-0000-000000000006', '51000000-0000-0000-0000-000000000005'),
    ('71000000-0000-0000-0000-000000000007', '51000000-0000-0000-0000-000000000007'),
    ('71000000-0000-0000-0000-000000000008', '51000000-0000-0000-0000-000000000008'),
    ('71000000-0000-0000-0000-000000000009', '51000000-0000-0000-0000-000000000009'),
    ('71000000-0000-0000-0000-000000000010', '51000000-0000-0000-0000-000000000010'),
    ('71000000-0000-0000-0000-000000000011', '51000000-0000-0000-0000-000000000012'),
    ('71000000-0000-0000-0000-000000000012', '51000000-0000-0000-0000-000000000001');

insert into public.inventory (partid, partname, cost, quantity, vehicletype)
values
    ('81000000-0000-0000-0000-000000000001', 'Rear tyre', 12000.00, 12, 'truck'),
    ('81000000-0000-0000-0000-000000000002', 'Valve set', 500.00, 30, 'truck'),
    ('81000000-0000-0000-0000-000000000003', 'Brake pad set', 4200.00, 10, 'bus'),
    ('81000000-0000-0000-0000-000000000004', 'Engine oil 15W-40', 1850.00, 24, 'truck'),
    ('81000000-0000-0000-0000-000000000005', 'Oil filter', 950.00, 18, 'truck'),
    ('81000000-0000-0000-0000-000000000006', 'Battery 12V', 6800.00, 6, 'car'),
    ('81000000-0000-0000-0000-000000000007', 'Wiper blade pair', 1250.00, 20, 'van'),
    ('81000000-0000-0000-0000-000000000008', 'Headlamp bulb', 850.00, 18, 'car');

insert into public.maintenance_task_parts (taskid, partid, quantityused, quantity, unit_price)
values
    ('71000000-0000-0000-0000-000000000003', '81000000-0000-0000-0000-000000000001', 2, 2, 12000.00),
    ('71000000-0000-0000-0000-000000000003', '81000000-0000-0000-0000-000000000002', 1, 1, 500.00),
    ('71000000-0000-0000-0000-000000000006', '81000000-0000-0000-0000-000000000002', 1, 1, 500.00),
    ('71000000-0000-0000-0000-000000000008', '81000000-0000-0000-0000-000000000008', 1, 1, 850.00),
    ('71000000-0000-0000-0000-000000000010', '81000000-0000-0000-0000-000000000007', 1, 1, 1250.00);

commit;

select 'users' as table_name, count(*) from public.users where userid::text like '11000000-%'
union all select 'drivers', count(*) from public.drivers where driverid::text like '31000000-%'
union all select 'maintenance_personnel', count(*) from public.maintenance_personnel where personnelid::text like '41000000-%'
union all select 'vehicles', count(*) from public.vehicles where vin::text like '51000000-%'
union all select 'trips', count(*) from public.trips where tripid::text like '61000000-%'
union all select 'work_orders', count(*) from public.maintenance_task where taskid::text like '71000000-%';
