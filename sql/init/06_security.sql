-- ============================================================================
-- 06_security.sql  --  RLS, policies, indexes, FK constraints (run after clean)
-- Idempotent: safe to run many times.
-- ============================================================================

-- --- enable RLS on every public table --------------------------------------
alter table public.customers     enable row level security;
alter table public.products      enable row level security;
alter table public.orders        enable row level security;
alter table public.stg_customers enable row level security;
alter table public.stg_products  enable row level security;
alter table public.stg_orders     enable row level security;
alter table public.etl_run_log   enable row level security;
alter table public.etl_rejects   enable row level security;

-- --- indexes on FK columns -------------------------------------------------
create index if not exists idx_orders_customer_id on public.orders(customer_id);
create index if not exists idx_orders_product_id  on public.orders(product_id);

-- --- policies: anon read, authenticated CRUD on prod tables -----------------
do $$
begin
  -- customers
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='customers' and policyname='customers_anon_read') then
    create policy customers_anon_read on public.customers for select to anon using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='customers' and policyname='customers_auth_all') then
    create policy customers_auth_all on public.customers for all to authenticated using (true) with check (true);
  end if;

  -- products
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='products' and policyname='products_anon_read') then
    create policy products_anon_read on public.products for select to anon using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='products' and policyname='products_auth_all') then
    create policy products_auth_all on public.products for all to authenticated using (true) with check (true);
  end if;

  -- orders
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='orders' and policyname='orders_anon_read') then
    create policy orders_anon_read on public.orders for select to anon using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='orders' and policyname='orders_auth_all') then
    create policy orders_auth_all on public.orders for all to authenticated using (true) with check (true);
  end if;

  -- etl_run_log: authenticated read only
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='etl_run_log' and policyname='etl_run_log_auth_read') then
    create policy etl_run_log_auth_read on public.etl_run_log for select to authenticated using (true);
  end if;

  -- etl_rejects: authenticated read only
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='etl_rejects' and policyname='etl_rejects_auth_read') then
    create policy etl_rejects_auth_read on public.etl_rejects for select to authenticated using (true);
  end if;
end $$;

-- --- FK constraints (nullable, on delete set null) -------------------------
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fk_orders_customer') then
    alter table public.orders
      add constraint fk_orders_customer
      foreign key (customer_id) references public.customers(customer_id)
      on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fk_orders_product') then
    alter table public.orders
      add constraint fk_orders_product
      foreign key (product_id) references public.products(product_id)
      on delete set null;
  end if;
end $$;
