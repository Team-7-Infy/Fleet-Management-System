begin;

-- ============================================================
-- Migration: Notifications unique constraint
-- Date: 2026-07-09
-- Description: Adds a unique constraint on (type, reference_id, recipient_id)
-- to prevent duplicate notifications. This works in conjunction with
-- the broadcast pattern (recipient_id IS NULL) — Postgres treats NULLs
-- as distinct, so each broadcast notification gets exactly one row per
-- (type, reference_id) combo.
-- ============================================================

-- First, remove any existing duplicates keeping the most recent row
delete from public.notifications n1
using public.notifications n2
where n1.id < n2.id
  and n1.type = n2.type
  and coalesce(n1.reference_id::text, '') = coalesce(n2.reference_id::text, '')
  and coalesce(n1.recipient_id::text, '') = coalesce(n2.recipient_id::text, '');

-- Create partial unique index for the broadcast case (recipient_id IS NULL)
create unique index if not exists idx_notifications_unique_broadcast
on public.notifications (type, reference_id)
where recipient_id is null;

-- Create partial unique index for the targeted case (recipient_id IS NOT NULL)
create unique index if not exists idx_notifications_unique_targeted
on public.notifications (type, reference_id, recipient_id)
where recipient_id is not null;

commit;