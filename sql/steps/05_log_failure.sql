-- ============================================================================
-- 05_log_failure.sql  --  ghi 1 dong that bai vao etl_run_log (goi boi Hop workflow)
-- ============================================================================
insert into public.etl_run_log
  (batch_id, pipeline_name, started_at, finished_at, status,
   rows_read, rows_written, rows_rejected, error_message, triggered_by)
values
  (gen_random_uuid(),
   'etl_to_db',
   now(),
   now(),
   'failed',
   0,
   0,
   0,
   'A workflow step failed; see the Hop audit log for details.',
   'workflow');
