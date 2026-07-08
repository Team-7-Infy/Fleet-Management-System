-- 20260709_fuel_logging_and_scheduling_timeout.sql
-- Implements: fuel_logs table, cancellation columns, pre-trip no-show timeout, post-trip overdue timeout

-- 1. Create fuel_logs table
create table if not exists public.fuel_logs (
    id uuid primary key default gen_random_uuid(),
    date timestamptz not null default now(),
    vehicle_id uuid not null references public.vehicles(vin),
    trip_id uuid references public.trips(tripid) on delete set null,
    driver_id uuid not null references public.drivers(driverid),
    fuel_type text not null check (fuel_type in ('Diesel', 'Petrol', 'CNG', 'Electric (EV)')),
    amount_requested numeric(10, 2),
    cost numeric(10, 2),
    volume_filled numeric(10, 2),
    price_per_liter numeric(10, 2),
    current_fuel_level numeric(5, 2),
    status text not null default 'Pending Approval' check (status in ('Pending Approval', 'Approved', 'Rejected', 'Completed')),
    receipt_code text,
    receipt_image_url text,
    kWh_added numeric(10, 2),
    charge_percent_before numeric(5, 2),
    charge_percent_after numeric(5, 2),
    is_approved boolean not null default false,
    approved_by uuid references public.users(userid) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_fuel_logs_trip on public.fuel_logs(trip_id);
create index if not exists idx_fuel_logs_vehicle on public.fuel_logs(vehicle_id);
create index if not exists idx_fuel_logs_driver on public.fuel_logs(driver_id);

alter table public.fuel_logs enable row level security;

create policy "fuel_logs_driver_own"
    on public.fuel_logs for all
    using (driver_id = auth.uid())
    with check (driver_id = auth.uid());

create policy "fuel_logs_fleet_manager_all"
    on public.fuel_logs for all
    using (
        exists (select 1 from public.fleet_manager where userid = auth.uid())
    );

-- 2. Trigger: sync approved fuel cost into trips.fuel_cost
create or replace function public.fn_sync_fuel_cost_to_trip()
returns trigger as $$
begin
    if new.trip_id is not null then
        update public.trips
        set fuel_cost = (
            select coalesce(sum(cost), 0)
            from public.fuel_logs
            where trip_id = new.trip_id and is_approved = true
        )
        where tripid = new.trip_id;
    end if;
    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_fuel_log_change on public.fuel_logs;
create trigger trg_fuel_log_change
    after insert or update of is_approved
    on public.fuel_logs
    for each row
    when (new.is_approved = true and new.trip_id is not null)
    execute function public.fn_sync_fuel_cost_to_trip();

-- 3. Add cancellation_reason and post_trip_flagged to trips
alter table public.trips
    add column if not exists cancellation_reason text;

alter table public.trips
    add column if not exists post_trip_flagged boolean not null default false;

-- 4. Refactor fn_sync_vehicle_status: release vehicle when post-trip deadline has passed
create or replace function public.fn_sync_vehicle_status(p_vin uuid)
returns void as $$
declare
    v_status text;
    v_current_status text;
    v_has_active_trip boolean;
    v_has_open_task boolean;
    v_has_pending_inspection boolean;
    v_most_recent_completed_trip_id uuid;
    v_post_trip_deadline timestamptz;
begin
    select status into v_current_status from public.vehicles where vin = p_vin;

    if v_current_status = 'out_of_service' then
        return;
    end if;

    select exists (
        select 1 from public.trips
        where vehicleid = p_vin
            and status in ('scheduled', 'pending', 'accepted', 'in_progress', 'rejection_pending')
    ) into v_has_active_trip;

    select exists (
        select 1 from public.task_vehicles tv
        join public.maintenance_task mt on tv.taskid = mt.taskid
        where tv.vin = p_vin and mt.status in ('scheduled', 'assigned', 'in_progress', 'on_hold')
    ) into v_has_open_task;

    select tripid into v_most_recent_completed_trip_id
    from public.trips
    where vehicleid = p_vin and status = 'completed'
    order by starttime desc
    limit 1;

    if v_most_recent_completed_trip_id is not null then
        select post_trip_inspection_due_at
        into v_post_trip_deadline
        from public.trips
        where tripid = v_most_recent_completed_trip_id;

        if v_post_trip_deadline is not null and v_post_trip_deadline <= now() then
            v_has_pending_inspection := false;
        else
            select not exists (
                select 1 from public.vehicle_inspections
                where trip_id = v_most_recent_completed_trip_id and type = 'post_trip'
            ) into v_has_pending_inspection;
        end if;
    else
        v_has_pending_inspection := false;
    end if;

    if v_has_active_trip or v_has_pending_inspection then
        v_status := 'assigned';
    elsif v_has_open_task then
        v_status := 'in_maintenance';
    else
        v_status := 'available';
    end if;

    if v_current_status is distinct from v_status then
        update public.vehicles set status = v_status where vin = p_vin;
    end if;
end;
$$ language plpgsql security definer;

-- 5. Pre-trip no-show processor (runs via cron every 5 minutes)
create or replace function public.fn_process_pretrip_noshows()
returns void as $$
declare
    v_trip record;
begin
    for v_trip in
        select t.tripid, t.driverid, t.vehicleid, t.starttime, t.startlocation, t.endlocation
        from public.trips t
        where t.status in ('scheduled', 'pending', 'accepted')
            and t.starttime + interval '1 hour' < now()
            and not exists (
                select 1 from public.vehicle_inspections vi
                where vi.trip_id = t.tripid and vi.type = 'pre_trip'
            )
    loop
        update public.trips
        set status = 'cancelled',
            cancellation_reason = 'no_show_pretrip',
            endtime = now()
        where tripid = v_trip.tripid;

        insert into public.driver_scores (driver_id, overall_score, calculated_at)
        values (v_trip.driverid, greatest(0, 100 - 25), now())
        on conflict (driver_id) do update
        set overall_score = greatest(0, driver_scores.overall_score - 25),
            calculated_at = now();

        insert into public.notifications (id, title, message, type, is_read, reference_id, recipient_id, created_at)
        select
            gen_random_uuid(),
            'Pre-Trip Inspection Missed',
            format('Driver missed pre-trip inspection for trip %s (%s → %s). Trip has been automatically cancelled with a 25-point penalty.',
                   v_trip.tripid::text, v_trip.startlocation, v_trip.endlocation),
            'pretrip_noshow',
            false,
            v_trip.tripid,
            fm.userid,
            now()
        from public.fleet_manager fm;

        perform public.fn_sync_vehicle_status(v_trip.vehicleid);
        perform public.fn_sync_driver_status(v_trip.driverid);
    end loop;
end;
$$ language plpgsql security definer;

-- 6. Post-trip overdue processor (runs via cron every 5 minutes)
create or replace function public.fn_process_posttrip_overdue()
returns void as $$
declare
    v_trip record;
begin
    for v_trip in
        select t.tripid, t.driverid, t.vehicleid, t.starttime, t.startlocation, t.endlocation
        from public.trips t
        where t.status = 'completed'
            and t.endtime + interval '2 hours' < now()
            and not exists (
                select 1 from public.vehicle_inspections vi
                where vi.trip_id = t.tripid and vi.type = 'post_trip'
            )
            and not t.post_trip_flagged
    loop
        update public.trips
        set post_trip_flagged = true
        where tripid = v_trip.tripid;

        insert into public.driver_scores (driver_id, overall_score, calculated_at)
        values (v_trip.driverid, greatest(0, 100 - 25), now())
        on conflict (driver_id) do update
        set overall_score = greatest(0, driver_scores.overall_score - 25),
            calculated_at = now();

        insert into public.notifications (id, title, message, type, is_read, reference_id, recipient_id, created_at)
        select
            gen_random_uuid(),
            'Post-Trip Inspection Overdue',
            format('Post-trip inspection for trip %s (%s → %s) is overdue. The vehicle has been released and a 25-point penalty has been applied.',
                   v_trip.tripid::text, v_trip.startlocation, v_trip.endlocation),
            'overdue_post_trip',
            false,
            v_trip.tripid,
            fm.userid,
            now()
        from public.fleet_manager fm;

        perform public.fn_sync_vehicle_status(v_trip.vehicleid);
        perform public.fn_sync_driver_status(v_trip.driverid);
    end loop;
end;
$$ language plpgsql security definer;

-- 7. Schedule cron jobs (pg_cron must be enabled in project)
select cron.schedule(
    'pretrip-noshow-check',
    '*/5 * * * *',
    'select public.fn_process_pretrip_noshows();'
);

select cron.schedule(
    'posttrip-overdue-check',
    '*/5 * * * *',
    'select public.fn_process_posttrip_overdue();'
);
