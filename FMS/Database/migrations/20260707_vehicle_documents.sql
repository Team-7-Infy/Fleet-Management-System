create table if not exists public.vehicle_documents (
    id uuid primary key default gen_random_uuid(),
    vehicle_id uuid not null references public.vehicles(vin) on delete cascade,
    doc_type text not null check (doc_type in ('insurance', 'registration', 'road_tax', 'permit', 'puc')),
    doc_number text not null,
    issue_date date not null,
    expiry_date date not null,
    file_url text,
    deleted_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_vehicle_docs_vehicle on public.vehicle_documents(vehicle_id);
create index if not exists idx_vehicle_docs_expiry on public.vehicle_documents(expiry_date);
