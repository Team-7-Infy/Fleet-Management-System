alter table public.maintenance_task
    drop constraint if exists maintenance_task_status_check;

alter table public.maintenance_task
    add constraint maintenance_task_status_check
        check (status in ('scheduled', 'assigned', 'in_progress', 'on_hold', 'completed', 'fake'));

alter table public.maintenance_task
    add column if not exists on_hold_reason text;

alter table public.maintenance_task
    add column if not exists on_hold_at timestamptz;
