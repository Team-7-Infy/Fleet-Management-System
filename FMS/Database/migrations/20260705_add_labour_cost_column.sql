alter table public.maintenance_task
    add column if not exists labour_cost numeric(12, 2) default 0;

comment on column public.maintenance_task.labour_cost is 'Labour cost portion of the work order (separate from parts cost in totalcost).';
