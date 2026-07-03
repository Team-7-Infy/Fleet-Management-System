insert into public.notifications (
    id,
    title,
    message,
    type,
    is_read,
    reference_id,
    recipient_id,
    created_at
)
values
    (
        '93000000-0000-0000-0000-000000000001',
        'Trip awaiting dispatch',
        'Rohan Sharma requested dispatch approval for Gurugram HQ to Delhi Airport Cargo.',
        'trips',
        false,
        '61000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000001',
        '2026-07-03T09:40:00Z'
    ),
    (
        '93000000-0000-0000-0000-000000000002',
        'Minor service delay',
        'Suresh Yadav reported that brake inspection is running behind schedule by 20 minutes.',
        'maintenance',
        false,
        '71000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000001',
        '2026-07-03T09:20:00Z'
    ),
    (
        '93000000-0000-0000-0000-000000000003',
        'Vehicle check completed',
        'HR26CR8841 passed inspection and is ready for assignment.',
        'vehicles',
        true,
        '51000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000001',
        '2026-07-03T08:55:00Z'
    ),
    (
        '93000000-0000-0000-0000-000000000004',
        'Driver profile added',
        'Isha Bansal is active and available for van assignments.',
        'users',
        false,
        '11000000-0000-0000-0000-000000000103',
        '11000000-0000-0000-0000-000000000001',
        '2026-07-03T08:30:00Z'
    ),
    (
        '93000000-0000-0000-0000-000000000005',
        'Daily summary ready',
        'Fleet health, trip completion, and open service reports are ready to review.',
        'system',
        true,
        null,
        '11000000-0000-0000-0000-000000000001',
        '2026-07-03T08:00:00Z'
    )
on conflict (id) do update
set title = excluded.title,
    message = excluded.message,
    type = excluded.type,
    is_read = excluded.is_read,
    reference_id = excluded.reference_id,
    recipient_id = excluded.recipient_id,
    created_at = excluded.created_at;
