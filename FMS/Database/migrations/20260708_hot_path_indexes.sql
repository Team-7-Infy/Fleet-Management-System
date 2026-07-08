-- Hot-path indexes for FM dashboard queries
-- Each of these columns is hit by per-row lookups in the N+1 loops found during
-- the FM dashboard performance audit. Adding these avoids sequential scans on
-- moderate-sized tables that are repeatedly queried per-task or per-vehicle.

create index if not exists idx_maintenance_task_parts_taskid
    on public.maintenance_task_parts (taskid);

create index if not exists idx_trips_driverid
    on public.trips (driverid);

create index if not exists idx_vehicle_inspections_vehicle_id
    on public.vehicle_inspections (vehicle_id);

create index if not exists idx_vehicle_inspections_driver_id
    on public.vehicle_inspections (driver_id);

create index if not exists idx_vehicle_inspections_trip_id
    on public.vehicle_inspections (trip_id);

create index if not exists idx_deviation_alert_tripid
    on public.deviation_alert (tripid);
