-- Add age column to vehicles table
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS age INTEGER;

-- Set random age between 1 and 8 for existing vehicles
UPDATE public.vehicles SET age = floor(random() * 8 + 1)::integer WHERE age IS NULL;
