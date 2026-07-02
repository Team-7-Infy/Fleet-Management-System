begin;

alter table public.users
    add column if not exists avatarurl text;

alter table public.maintenance_task
    add column if not exists title text,
    add column if not exists reporteddate timestamptz default now(),
    add column if not exists completedat timestamptz,
    add column if not exists timetakenhours numeric(8, 2),
    add column if not exists partssummary text,
    add column if not exists totalcost numeric(12, 2),
    add column if not exists photourls text[] default '{}';

create index if not exists idx_users_role_avatar
    on public.users (role)
    where avatarurl is not null;

create index if not exists idx_maintenance_task_status_reporteddate
    on public.maintenance_task (status, reporteddate desc);

comment on column public.users.avatarurl is 'Optional user profile/display photo URL.';
comment on column public.maintenance_task.title is 'Short service/work-order title shown on manager cards.';
comment on column public.maintenance_task.reporteddate is 'Timestamp when the service was reported.';
comment on column public.maintenance_task.completedat is 'Timestamp when the service was completed.';
comment on column public.maintenance_task.timetakenhours is 'Total service time in hours.';
comment on column public.maintenance_task.partssummary is 'Human-readable summary of parts used.';
comment on column public.maintenance_task.totalcost is 'Total completed-service cost.';
comment on column public.maintenance_task.photourls is 'Optional service photo URLs.';

commit;
