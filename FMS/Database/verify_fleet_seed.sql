-- Run this in the same Supabase SQL editor after the seed.
-- If bad_vehicle_count is not 0, the cleanup did not affect those rows.
-- If seeded_vehicle_count is 0, the app is likely pointed at a different Supabase project/config.

select
    count(*) filter (
        where regexp_replace(licence_plate, '[[:space:]]+', '', 'g') in ('UK071234', 'UK07AJ9125', 'UL043456')
           or lower(coalesce(make, '') || ' ' || coalesce(model, '')) ilike any (array[
                '%that%lead%',
                '%saw safe%',
                '%mercedes abcd%'
           ])
    ) as bad_vehicle_count,
    count(*) filter (
        where vin in (
            '50000000-0000-0000-0000-000000000001',
            '50000000-0000-0000-0000-000000000002',
            '50000000-0000-0000-0000-000000000003',
            '50000000-0000-0000-0000-000000000004'
        )
    ) as seeded_vehicle_count
from public.vehicles;

select licence_plate, year, make, model, status, vehicletype
from public.vehicles
order by licence_plate;
