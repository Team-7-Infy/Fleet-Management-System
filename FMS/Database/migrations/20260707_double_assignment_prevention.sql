-- Trigger function to check driver assignment overlaps on active trips
CREATE OR REPLACE FUNCTION check_driver_trip_overlap()
RETURNS TRIGGER AS $$
BEGIN
    -- Only check if a driver is assigned and the trip status is active
    IF NEW.driverid IS NOT NULL AND NEW.status IN ('scheduled', 'pending', 'accepted', 'rejection_pending', 'in_progress') THEN
        IF EXISTS (
            SELECT 1 FROM trips
            WHERE tripid <> NEW.tripid
              AND driverid = NEW.driverid
              AND status IN ('scheduled', 'pending', 'accepted', 'rejection_pending', 'in_progress')
              -- Overlap check: starttime < other_endtime AND endtime > other_starttime
              AND starttime < COALESCE(NEW.endtime, NEW.starttime + INTERVAL '2 hours')
              AND COALESCE(endtime, starttime + INTERVAL '2 hours') > NEW.starttime
        ) THEN
            RAISE EXCEPTION 'Driver is already assigned to an overlapping active trip.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to the trips table
DROP TRIGGER IF EXISTS trg_check_driver_trip_overlap ON trips;
CREATE TRIGGER trg_check_driver_trip_overlap
BEFORE INSERT OR UPDATE OF driverid, starttime, endtime, status ON trips
FOR EACH ROW
EXECUTE FUNCTION check_driver_trip_overlap();


-- Trigger function to check vehicle assignment overlaps on active trips
CREATE OR REPLACE FUNCTION check_vehicle_trip_overlap()
RETURNS TRIGGER AS $$
BEGIN
    -- Only check if a vehicle is assigned and the trip status is active
    IF NEW.vehicleid IS NOT NULL AND NEW.status IN ('scheduled', 'pending', 'accepted', 'rejection_pending', 'in_progress') THEN
        IF EXISTS (
            SELECT 1 FROM trips
            WHERE tripid <> NEW.tripid
              AND vehicleid = NEW.vehicleid
              AND status IN ('scheduled', 'pending', 'accepted', 'rejection_pending', 'in_progress')
              -- Overlap check: starttime < other_endtime AND endtime > other_starttime
              AND starttime < COALESCE(NEW.endtime, NEW.starttime + INTERVAL '2 hours')
              AND COALESCE(endtime, starttime + INTERVAL '2 hours') > NEW.starttime
        ) THEN
            RAISE EXCEPTION 'Vehicle is already assigned to an overlapping active trip.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to the trips table
DROP TRIGGER IF EXISTS trg_check_vehicle_trip_overlap ON trips;
CREATE TRIGGER trg_check_vehicle_trip_overlap
BEFORE INSERT OR UPDATE OF vehicleid, starttime, endtime, status ON trips
FOR EACH ROW
EXECUTE FUNCTION check_vehicle_trip_overlap();
