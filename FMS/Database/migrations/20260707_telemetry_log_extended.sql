ALTER TABLE telemetry_log ADD COLUMN tripid UUID REFERENCES trips(tripid) ON DELETE SET NULL;
ALTER TABLE telemetry_log ADD COLUMN vehicleid UUID REFERENCES vehicles(vin) ON DELETE SET NULL;
ALTER TABLE telemetry_log ADD COLUMN heading DOUBLE PRECISION;
CREATE INDEX idx_telemetry_trip ON telemetry_log(tripid);
CREATE INDEX idx_telemetry_vehicle ON telemetry_log(vehicleid);
