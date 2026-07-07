-- Create vehicle health scores cache table
CREATE TABLE IF NOT EXISTS vehicle_health_scores (
    vehicle_id UUID PRIMARY KEY REFERENCES vehicles(vin) ON DELETE CASCADE,
    overall_score INT NOT NULL,
    age_score INT NOT NULL,
    fuel_efficiency_score INT NOT NULL,
    maintenance_adherence_score INT NOT NULL,
    inspection_score INT NOT NULL,
    maintenance_burden_score INT NOT NULL,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable Row Level Security (RLS)
ALTER TABLE vehicle_health_scores ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read vehicle health scores
CREATE POLICY "All authenticated can read vehicle_health_scores"
ON vehicle_health_scores FOR SELECT
TO authenticated
USING (true);

-- Allow authenticated services to insert/update scores
CREATE POLICY "All authenticated can write vehicle_health_scores"
ON vehicle_health_scores FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
