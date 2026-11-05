-- ============================================================================
-- 04_log_run.sql  --  ghi 1 dong thanh cong vao etl_run_log (goi boi Hop workflow)
-- ============================================================================
insert into public.etl_run_log
  (batch_id, pipeline_name, started_at, finished_at, status,
   rows_read, rows_written, rows_rejected, triggered_by)
values
  (gen_random_uuid(),
   'etl_to_db',
   now(),
   now(),
   'success',
   (select count(*) from public.stg_customers)
     + (select count(*) from public.stg_products)
     + (select count(*) from public.stg_orders),
   (select count(*) from public.customers)
     + (select count(*) from public.products)
     + (select count(*) from public.orders),
   0,
   'workflow');
