CREATE TABLE IF NOT EXISTS public.vehicle_health_scores (
    vehicle_id UUID PRIMARY KEY REFERENCES public.vehicles(vin) ON DELETE CASCADE,
    score INT NOT NULL,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
