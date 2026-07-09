-- 20260710_driver_score_penalties_and_backfill.sql
-- 1. Update cron functions to use driver_score_penalties table instead of direct overall_score decrement
-- 2. Backfill driver_scores for drivers with completed trips but no score

-- 1a. Update pre-trip no-show processor
create or replace function public.fn_process_pretrip_noshows()
returns void as $$
declare
    v_trip record;
    v_driver_id uuid;
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
        v_driver_id := v_trip.driverid;

        update public.trips
        set status = 'cancelled',
            cancellation_reason = 'no_show_pretrip',
            endtime = now()
        where tripid = v_trip.tripid;

        -- Insert penalty record instead of decrementing overall_score directly
        insert into public.driver_score_penalties (driver_id, points, reason, applied_at, expires_at)
        values (v_driver_id, 25, 'Pre-trip inspection no-show: trip ' || v_trip.tripid::text, now(), now() + interval '90 days')
        on conflict do nothing;

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

-- 1b. Update post-trip overdue processor
create or replace function public.fn_process_posttrip_overdue()
returns void as $$
declare
    v_trip record;
    v_driver_id uuid;
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
        v_driver_id := v_trip.driverid;

        update public.trips
        set post_trip_flagged = true
        where tripid = v_trip.tripid;

        -- Insert penalty record instead of decrementing overall_score directly
        insert into public.driver_score_penalties (driver_id, points, reason, applied_at, expires_at)
        values (v_driver_id, 25, 'Post-trip inspection overdue: trip ' || v_trip.tripid::text, now(), now() + interval '90 days')
        on conflict do nothing;

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

-- 2. Backfill is handled by UserManagementService.backfillMissingDriverScores() in Swift.
--    That method queries for drivers with completed trips but no driver_scores row,
--    then calls the existing calculateAndUpsertDriverScore() per driver, which
--    computes real scores (inspection, geofence, compliance, mileage, penalties).
--    Run it from the Manager Users screen via the "Backfill Missing" action.
