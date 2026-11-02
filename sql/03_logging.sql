-- =============================================================================
-- 03_logging.sql  -  run log + reject log for observability (P4)
-- =============================================================================
create table if not exists public.etl_run_log (
    run_id        bigserial primary key,
    batch_id      uuid not null,
    pipeline_name text not null,
    started_at    timestamptz not null default now(),
    finished_at   timestamptz,
    status        text not null default 'running',   -- running / success / failed
    rows_read     bigint default 0,
    rows_written  bigint default 0,
    rows_rejected bigint default 0,
    error_message text,
    host          text,
    triggered_by  text   -- manual / schedule / api / drive_watch
);

create table if not exists public.etl_rejects (
    reject_id     bigserial primary key,
    batch_id      uuid not null,
    pipeline_name text not null,
    transform_name text,
    reject_reason text not null,
    raw_payload   jsonb,
    created_at    timestamptz not null default now()
);

create index if not exists idx_etl_run_log_batch on public.etl_run_log(batch_id);
create index if not exists idx_etl_rejects_batch on public.etl_rejects(batch_id);

-- helper to open a run (returns run_id)
create or replace function public.etl_run_start(p_batch uuid, p_pipeline text, p_triggered_by text)
returns bigint language plpgsql as $$
declare v bigint;
begin
    insert into public.etl_run_log (batch_id, pipeline_name, triggered_by, host)
    values (p_batch, p_pipeline, p_triggered_by, inet_client_addr()::text)
    returning run_id into v;
    return v;
end;
$$;

create or replace function public.etl_run_finish(p_run bigint, p_status text,
                                                p_read bigint, p_written bigint, p_rejected bigint,
                                                p_error text default null)
returns void language plpgsql as $$
begin
    update public.etl_run_log
       set finished_at   = now(),
           status        = p_status,
           rows_read     = p_read,
           rows_written  = p_written,
           rows_rejected = p_rejected,
           error_message = p_error
     where run_id = p_run;
end;
$$;