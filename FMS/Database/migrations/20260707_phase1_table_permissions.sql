-- Grant table permissions to Supabase roles
grant all on public.vehicle_documents to anon, authenticated, service_role;
grant all on public.driver_scores to anon, authenticated, service_role;
grant all on public.driver_schedules to anon, authenticated, service_role;
grant all on public.vehicle_inspections to anon, authenticated, service_role;
grant all on public.inspection_items to anon, authenticated, service_role;
grant all on public.expense_entries to anon, authenticated, service_role;

-- Enable RLS with wide-open policies (matching codebase convention)
alter table public.vehicle_documents enable row level security;
alter table public.driver_scores enable row level security;
alter table public.driver_schedules enable row level security;
alter table public.vehicle_inspections enable row level security;
alter table public.inspection_items enable row level security;
alter table public.expense_entries enable row level security;

create policy "vehicle_documents_all_authenticated" on public.vehicle_documents
    for all to authenticated using (true) with check (true);
create policy "driver_scores_all_authenticated" on public.driver_scores
    for all to authenticated using (true) with check (true);
create policy "driver_schedules_all_authenticated" on public.driver_schedules
    for all to authenticated using (true) with check (true);
create policy "vehicle_inspections_all_authenticated" on public.vehicle_inspections
    for all to authenticated using (true) with check (true);
create policy "inspection_items_all_authenticated" on public.inspection_items
    for all to authenticated using (true) with check (true);
create policy "expense_entries_all_authenticated" on public.expense_entries
    for all to authenticated using (true) with check (true);
