create policy "notifications_delete_own" on public.notifications
    for delete using (recipient_id = auth.uid());
