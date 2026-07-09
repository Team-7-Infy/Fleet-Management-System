-- 20260710_cleanup_broken_backfill_rows.sql
-- Cleanup rows created by the broken SQL backfill in the previous 20260710 migration.
-- The PL/pgSQL loop had a bug where each SELECT ... INTO v_score_row overwrote
-- the entire record, so all factor scores (inspection, geofence, compliance,
-- mileage) were NULL and the inserted overall_score was 0 (null arithmetic coalesced).
-- These need to be removed so UserManagementService.backfillMissingDriverScores()
-- can recompute real values from scratch.
DELETE FROM public.driver_scores
WHERE inspection_false_rate IS NULL
  AND geofence_violation_rate IS NULL
  AND compliance_violation_rate IS NULL
  AND mileage_accuracy IS NULL
  AND overall_score = 0;
