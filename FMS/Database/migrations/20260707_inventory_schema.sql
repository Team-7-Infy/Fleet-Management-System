alter table public.inventory
    add column if not exists sku text,
    add column if not exists description text,
    add column if not exists category text,
    add column if not exists unit text,
    add column if not exists reorderlevel integer,
    add column if not exists unitcost numeric(12, 2);
