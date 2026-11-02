-- ============================================================================
-- 01_staging.sql  --  chay trong Supabase SQL Editor TRUOC khi chay pipeline
-- Tao 3 bang staging (all text, giu nguyen du lieu tho tu Google Drive)
-- ============================================================================

create table if not exists public.stg_customers (
  customerid  text,
  fullname    text,
  email       text,
  phone       text,
  city        text,
  country     text,
  signupdate  text,
  status      text,
  gender      text,
  _loaded_at  timestamptz default now()
);

create table if not exists public.stg_products (
  productid   text,
  productname text,
  category    text,
  unitprice   text,
  currency    text,
  stock       text,
  updatedat   text,
  _loaded_at  timestamptz default now()
);

create table if not exists public.stg_orders (
  orderid       text,
  customerid    text,
  productid     text,
  quantity      text,
  unitprice     text,
  orderdate     text,
  status        text,
  paymentmethod text,
  shippingcity  text,
  _loaded_at    timestamptz default now()
);

-- ---------------------------------------------------------------------------
-- Ham phu tro: parse ngay an toan tu nhieu dinh dang (khong bao gio nem loi)
-- ---------------------------------------------------------------------------
create or replace function public.safe_date(txt text)
returns date
language plpgsql
immutable
as $$
declare
  s text := btrim(coalesce(txt, ''));
  d date;
begin
  if s = '' then return null; end if;

  -- yyyy-mm-dd (ke ca co gio phia sau: 2024-01-03 00:00:00)
  begin
    d := to_date(substr(s, 1, 10), 'YYYY-MM-DD');
    if d is not null then return d; end if;
  exception when others then null;
  end;

  -- dd/mm/yyyy  (uu tien kieu Viet Nam)
  begin
    d := to_date(s, 'DD/MM/YYYY');
    if d is not null then return d; end if;
  exception when others then null;
  end;

  -- dd-mm-yyyy
  begin
    d := to_date(s, 'DD-MM-YYYY');
    if d is not null then return d; end if;
  exception when others then null;
  end;

  -- mm/dd/yyyy
  begin
    d := to_date(s, 'MM/DD/YYYY');
    if d is not null then return d; end if;
  exception when others then null;
  end;

  -- yyyy/mm/dd
  begin
    d := to_date(s, 'YYYY/MM/DD');
    if d is not null then return d; end if;
  exception when others then null;
  end;

  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Ham phu tro: parse gia tien ("$1,200.50", "1.200.000", -50000, 0, rong)
-- Tra ve null neu khong hop le (am / bang 0 / khong phai so)
-- ---------------------------------------------------------------------------
create or replace function public.parse_price(txt text)
returns numeric
language plpgsql
immutable
as $$
declare
  s text := btrim(coalesce(txt, ''));
  n numeric;
begin
  if s = '' then return null; end if;

  s := replace(s, '$', '');
  s := replace(s, '₫', '');
  s := replace(s, 'đ', '');
  s := replace(s, ' ', '');

  -- 1,200.50  (dau phay phan nghin, cham thap phan)
  if s ~ '^-?[0-9]{1,3}(,[0-9]{3})+(\.([0-9]+))?$' then
    s := replace(s, ',', '');
  -- 1.200.000 (dau cham phan nghin, khong co thap phan)
  elsif s ~ '^-?[0-9]{1,3}(\.([0-9]{3}))+$' then
    s := replace(s, '.', '');
  end if;

  begin
    n := s::numeric;
  exception when others then
    return null;
  end;

  if n is null or n <= 0 then return null; end if;
  return n;
end;
$$;

-- ---------------------------------------------------------------------------
-- Ham phu tro: chuan hoa ten thanh pho (Viet tat / khong dau / ten cu / CAPS)
-- ---------------------------------------------------------------------------
create or replace function public.norm_city(txt text)
returns text
language plpgsql
immutable
as $$
declare
  s text := lower(btrim(coalesce(txt, '')));
begin
  s := replace(s, '.', '');
  s := regexp_replace(s, '\s+', ' ', 'g');

  if s = '' then return null; end if;

  if s in ('hcm','hcm city','tp hcm','tphcm','ho chi minh','ho chi minh city',
           'sai gon','saigon','sg','tp ho chi minh') then
    return 'Ho Chi Minh';
  end if;
  if s in ('ha noi','hanoi','hn','ha noi city','thu do ha noi') then
    return 'Ha Noi';
  end if;
  if s in ('da nang','danang','dn','đà nẵng','da nang city') then
    return 'Da Nang';
  end if;
  if s in ('hai phong','haiphong','hp','hải phòng') then
    return 'Hai Phong';
  end if;
  if s in ('can tho','cantho','ct','cần thơ') then
    return 'Can Tho';
  end if;

  return initcap(s);
end;
$$;
