create table if not exists public.notifications (
    notificationid uuid primary key default gen_random_uuid(),
    recipient_userid uuid not null references public.users(userid) on delete cascade,
    actor_userid uuid references public.users(userid) on delete set null,
    category text not null check (category in ('trips', 'maintenance', 'vehicles', 'users', 'system')),
    title text not null,
    message text not null,
    related_table text,
    related_id uuid,
    is_read boolean not null default false,
    createdat timestamptz not null default now()
);

create index if not exists notifications_recipient_created_idx
    on public.notifications (recipient_userid, createdat desc);

create index if not exists notifications_recipient_category_idx
    on public.notifications (recipient_userid, category);

alter table public.notifications enable row level security;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'notifications'
          and policyname = 'notifications_select_own'
    ) then
        create policy notifications_select_own
            on public.notifications
            for select
            using (recipient_userid = auth.uid());
    end if;

    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'notifications'
          and policyname = 'notifications_update_own'
    ) then
        create policy notifications_update_own
            on public.notifications
            for update
            using (recipient_userid = auth.uid())
            with check (recipient_userid = auth.uid());
    end if;
end $$;

insert into public.notifications (
    notificationid,
    recipient_userid,
    actor_userid,
    category,
    title,
    message,
    related_table,
    related_id,
    is_read,
    createdat
)
values
    (
        '91000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000101',
        'trips',
        'Trip started',
        'Rohan Sharma started Gurugram Logistics Hub to Jaipur Warehouse.',
        'trips',
        '61000000-0000-0000-0000-000000000001',
        false,
        '2026-07-01T10:20:00Z'
    ),
    (
        '91000000-0000-0000-0000-000000000002',
        '11000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000101',
        'trips',
        'Delay reported',
        'Rohan Sharma reported traffic delay near Manesar toll.',
        'trips',
        '61000000-0000-0000-0000-000000000001',
        false,
        '2026-07-01T10:05:00Z'
    ),
    (
        '91000000-0000-0000-0000-000000000003',
        '11000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000201',
        'maintenance',
        'Work order updated',
        'Suresh Yadav moved Brake pad inspection to in progress.',
        'maintenance_task',
        '71000000-0000-0000-0000-000000000001',
        false,
        '2026-07-01T09:45:00Z'
    ),
    (
        '91000000-0000-0000-0000-000000000004',
        '11000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000201',
        'maintenance',
        'Parts requested',
        'Suresh Yadav requested brake pads and cleaner for the urgent service.',
        'maintenance_task',
        '71000000-0000-0000-0000-000000000001',
        false,
        '2026-07-01T09:30:00Z'
    ),
    (
        '91000000-0000-0000-0000-000000000005',
        '11000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000201',
        'vehicles',
        'Vehicle marked maintenance',
        'Suresh Yadav marked UL04 3456 ready for brake inspection.',
        'vehicles',
        '51000000-0000-0000-0000-000000000003',
        true,
        '2026-07-01T09:10:00Z'
    ),
    (
        '91000000-0000-0000-0000-000000000006',
        '11000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000101',
        'users',
        'Driver profile updated',
        'Rohan Sharma updated contact and license details.',
        'users',
        '11000000-0000-0000-0000-000000000101',
        true,
        '2026-07-01T08:40:00Z'
    ),
    (
        '91000000-0000-0000-0000-000000000007',
        '11000000-0000-0000-0000-000000000001',
        null,
        'system',
        'Daily fleet summary',
        'Three trips pending, two vehicles in maintenance, and four open work orders.',
        null,
        null,
        false,
        '2026-07-01T08:00:00Z'
    )
on conflict (notificationid) do update
set recipient_userid = excluded.recipient_userid,
    actor_userid = excluded.actor_userid,
    category = excluded.category,
    title = excluded.title,
    message = excluded.message,
    related_table = excluded.related_table,
    related_id = excluded.related_id,
    is_read = excluded.is_read,
    createdat = excluded.createdat;

select category, count(*) as notification_count
from public.notifications
where recipient_userid = '11000000-0000-0000-0000-000000000001'
group by category
order by category;
