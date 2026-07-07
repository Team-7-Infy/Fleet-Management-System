-- 1. Vehicle Status Recalculation Function
CREATE OR REPLACE FUNCTION fn_sync_vehicle_status(p_vin uuid)
RETURNS void AS $$
DECLARE
  v_status text;
  v_current_status text;
  v_has_active_trip boolean;
  v_has_open_task boolean;
  v_has_pending_inspection boolean;
  v_most_recent_completed_trip_id uuid;
BEGIN
  -- Get current status of the vehicle
  SELECT status INTO v_current_status FROM public.vehicles WHERE vin = p_vin;
  
  -- If vehicle is out of service, leave it as out_of_service
  IF v_current_status = 'out_of_service' THEN
    RETURN;
  END IF;

  -- Check active/scheduled/pending trips
  SELECT EXISTS (
    SELECT 1 FROM public.trips 
    WHERE vehicleid = p_vin 
      AND status IN ('scheduled', 'pending', 'accepted', 'in_progress', 'rejection_pending')
  ) INTO v_has_active_trip;

  -- Check open maintenance tasks
  SELECT EXISTS (
    SELECT 1 FROM public.task_vehicles tv
    JOIN public.maintenance_task mt ON tv.taskid = mt.taskid
    WHERE tv.vin = p_vin AND mt.status IN ('scheduled', 'assigned', 'in_progress', 'on_hold')
  ) INTO v_has_open_task;

  -- Check post-trip inspection for the most recent completed trip
  SELECT tripid INTO v_most_recent_completed_trip_id
  FROM public.trips
  WHERE vehicleid = p_vin AND status = 'completed'
  ORDER BY starttime DESC
  LIMIT 1;

  IF v_most_recent_completed_trip_id IS NOT NULL THEN
    SELECT NOT EXISTS (
      SELECT 1 FROM public.vehicle_inspections
      WHERE trip_id = v_most_recent_completed_trip_id AND type = 'post_trip'
    ) INTO v_has_pending_inspection;
  ELSE
    v_has_pending_inspection := false;
  END IF;

  -- Determine final status
  IF v_has_active_trip OR v_has_pending_inspection THEN
    v_status := 'assigned';
  ELSIF v_has_open_task THEN
    v_status := 'in_maintenance';
  ELSE
    v_status := 'available';
  END IF;

  -- Update only if changed
  IF v_current_status IS DISTINCT FROM v_status THEN
    UPDATE public.vehicles SET status = v_status WHERE vin = p_vin;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Driver Status Recalculation Function
CREATE OR REPLACE FUNCTION fn_sync_driver_status(p_driver_id uuid)
RETURNS void AS $$
DECLARE
  v_status text;
  v_current_status text;
  v_has_active_trip boolean;
  v_has_scheduled_trip boolean;
BEGIN
  -- Get current status of the driver
  SELECT status INTO v_current_status FROM public.drivers WHERE driverid = p_driver_id;
  
  -- If driver is unavailable, leave it as unavailable
  IF v_current_status = 'unavailable' THEN
    RETURN;
  END IF;

  -- Check active trip (in progress or accepted)
  SELECT EXISTS (
    SELECT 1 FROM public.trips
    WHERE driverid = p_driver_id AND status IN ('accepted', 'in_progress')
  ) INTO v_has_active_trip;

  -- Check scheduled trip (scheduled, pending, rejection_pending)
  SELECT EXISTS (
    SELECT 1 FROM public.trips
    WHERE driverid = p_driver_id AND status IN ('scheduled', 'pending', 'rejection_pending')
  ) INTO v_has_scheduled_trip;

  -- Determine status
  IF v_has_active_trip THEN
    v_status := 'on_trip';
  ELSIF v_has_scheduled_trip THEN
    v_status := 'scheduled';
  ELSE
    v_status := 'available';
  END IF;

  -- Update only if changed
  IF v_current_status IS DISTINCT FROM v_status THEN
    UPDATE public.drivers SET status = v_status WHERE driverid = p_driver_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Mechanic (Personnel) Status Recalculation Function
CREATE OR REPLACE FUNCTION fn_sync_mechanic_status(p_personnel_id uuid)
RETURNS void AS $$
DECLARE
  v_status text;
  v_current_status text;
  v_has_active_work boolean;
BEGIN
  -- Get current status of the mechanic
  SELECT status INTO v_current_status FROM public.maintenance_personnel WHERE personnelid = p_personnel_id;
  
  -- If mechanic is unavailable, leave it as unavailable
  IF v_current_status = 'unavailable' THEN
    RETURN;
  END IF;

  -- Check active task (in progress)
  SELECT EXISTS (
    SELECT 1 FROM public.maintenance_task
    WHERE executedby = p_personnel_id AND status = 'in_progress'
  ) INTO v_has_active_work;

  -- Determine status
  IF v_has_active_work THEN
    v_status := 'in_service';
  ELSE
    v_status := 'available';
  END IF;

  -- Update only if changed
  IF v_current_status IS DISTINCT FROM v_status THEN
    UPDATE public.maintenance_personnel SET status = v_status WHERE personnelid = p_personnel_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Trigger on public.trips
CREATE OR REPLACE FUNCTION trg_on_trip_change()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.vehicleid IS NOT NULL THEN
      PERFORM fn_sync_vehicle_status(NEW.vehicleid);
    END IF;
    IF NEW.driverid IS NOT NULL THEN
      PERFORM fn_sync_driver_status(NEW.driverid);
    END IF;
    
    -- If driver or vehicle changed, sync the old ones too
    IF TG_OP = 'UPDATE' THEN
      IF OLD.vehicleid IS NOT NULL AND OLD.vehicleid IS DISTINCT FROM NEW.vehicleid THEN
        PERFORM fn_sync_vehicle_status(OLD.vehicleid);
      END IF;
      IF OLD.driverid IS NOT NULL AND OLD.driverid IS DISTINCT FROM NEW.driverid THEN
        PERFORM fn_sync_driver_status(OLD.driverid);
      END IF;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.vehicleid IS NOT NULL THEN
      PERFORM fn_sync_vehicle_status(OLD.vehicleid);
    END IF;
    IF OLD.driverid IS NOT NULL THEN
      PERFORM fn_sync_driver_status(OLD.driverid);
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_trip_change ON public.trips;
CREATE TRIGGER trg_trip_change
AFTER INSERT OR UPDATE OR DELETE ON public.trips
FOR EACH ROW EXECUTE FUNCTION trg_on_trip_change();


-- 5. Trigger on public.vehicle_inspections
CREATE OR REPLACE FUNCTION trg_on_inspection_change()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.vehicle_id IS NOT NULL THEN
      PERFORM fn_sync_vehicle_status(NEW.vehicle_id);
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.vehicle_id IS NOT NULL THEN
      PERFORM fn_sync_vehicle_status(OLD.vehicle_id);
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inspection_change ON public.vehicle_inspections;
CREATE TRIGGER trg_inspection_change
AFTER INSERT OR UPDATE OR DELETE ON public.vehicle_inspections
FOR EACH ROW EXECUTE FUNCTION trg_on_inspection_change();


-- 6. Trigger on public.maintenance_task
CREATE OR REPLACE FUNCTION trg_on_maintenance_task_change()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.executedby IS NOT NULL THEN
      PERFORM fn_sync_mechanic_status(NEW.executedby);
    END IF;
    
    IF TG_OP = 'UPDATE' AND OLD.executedby IS NOT NULL AND OLD.executedby IS DISTINCT FROM NEW.executedby THEN
      PERFORM fn_sync_mechanic_status(OLD.executedby);
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.executedby IS NOT NULL THEN
      PERFORM fn_sync_mechanic_status(OLD.executedby);
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_maintenance_task_change ON public.maintenance_task;
CREATE TRIGGER trg_maintenance_task_change
AFTER INSERT OR UPDATE OR DELETE ON public.maintenance_task
FOR EACH ROW EXECUTE FUNCTION trg_on_maintenance_task_change();


-- 7. Trigger on public.task_vehicles
CREATE OR REPLACE FUNCTION trg_on_task_vehicle_change()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.vin IS NOT NULL THEN
      PERFORM fn_sync_vehicle_status(NEW.vin);
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.vin IS NOT NULL AND OLD.vin IS DISTINCT FROM NEW.vin THEN
      PERFORM fn_sync_vehicle_status(OLD.vin);
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.vin IS NOT NULL THEN
      PERFORM fn_sync_vehicle_status(OLD.vin);
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_task_vehicle_change ON public.task_vehicles;
CREATE TRIGGER trg_task_vehicle_change
AFTER INSERT OR UPDATE OR DELETE ON public.task_vehicles
FOR EACH ROW EXECUTE FUNCTION trg_on_task_vehicle_change();
