-- ============================================================================
-- 02_clean.sql  --  chay SAU khi pipeline 02_drive_to_supabase da do du lieu
-- Tu 3 bang staging -> 3 bang sach (upsert, chay lai nhieu lan khong bi trung)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- BANG DICH
-- ---------------------------------------------------------------------------
create table if not exists public.customers (
  customer_id    text primary key,
  full_name      text,
  email          text,
  is_email_valid boolean not null default false,
  phone          text,
  city           text,
  country        char(2),
  signup_date    date,
  status         text,
  gender         text,
  loaded_at      timestamptz not null default now()
);

create table if not exists public.products (
  product_id   text primary key,
  product_name text,
  category     text,
  unit_price   numeric(14,2),
  currency     char(3),
  stock        integer,
  updated_at   date,
  loaded_at    timestamptz not null default now()
);

create table if not exists public.orders (
  order_id           text primary key,
  customer_id        text,
  product_id         text,
  quantity           integer,
  unit_price         numeric(14,2),
  line_total         numeric(16,2) generated always as (quantity * unit_price) stored,
  order_date         date,
  status             text,
  payment_method     text,
  shipping_city      text,
  is_customer_valid  boolean not null default false,
  is_product_valid   boolean not null default false,
  is_quantity_valid  boolean not null default false,
  is_future_date     boolean not null default false,
  price_mismatch     boolean not null default false,
  loaded_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- CUSTOMERS
-- ---------------------------------------------------------------------------
with src as (
  select
    upper(btrim(customerid))            as customer_id,
    btrim(fullname)                     as full_name,
    lower(btrim(coalesce(email, '')))   as email,
    btrim(coalesce(phone, ''))          as phone,
    city, country, signupdate, status, gender, _loaded_at
  from public.stg_customers
),
dedup as (
  select *,
         row_number() over (
           partition by customer_id
           order by (public.safe_date(signupdate) is null), _loaded_at desc
         ) as rn
  from src
  where customer_id is not null and customer_id <> ''
),
cleaned as (
  select
    customer_id,
    nullif(initcap(regexp_replace(regexp_replace(full_name,
      '[^A-Za-zÀ-ỹ0-9 .''-]', '', 'g'), '\s+', ' ', 'g')), '') as full_name,
    case when email ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' then email end as email,
    (email ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$')                  as is_email_valid,
    case
      when regexp_replace(phone, '[^0-9]', '', 'g') ~ '^84[0-9]{9}$'
        then '0' || substr(regexp_replace(phone, '[^0-9]', '', 'g'), 3)
      when length(regexp_replace(phone, '[^0-9]', '', 'g')) in (10, 11)
        then regexp_replace(phone, '[^0-9]', '', 'g')
    end as phone,
    public.norm_city(city) as city,
    case
      when lower(btrim(coalesce(country, ''))) in ('vn','vietnam','viet nam','viet-nam') then 'VN'
      when lower(btrim(coalesce(country, ''))) in ('','n/a','na','none','null') then null
      else upper(left(btrim(country), 2))
    end as country,
    public.safe_date(signupdate) as signup_date,
    case
      when lower(btrim(coalesce(status, ''))) in ('','null') then 'unknown'
      when lower(btrim(status)) in ('active','inactive','pending') then lower(btrim(status))
      else lower(btrim(status))
    end as status,
    case
      when lower(btrim(coalesce(gender, ''))) in ('nam','male','m','1')  then 'male'
      when lower(btrim(coalesce(gender, ''))) in ('nữ','nu','female','f','0') then 'female'
    end as gender
  from dedup
  where rn = 1
)
insert into public.customers
  (customer_id, full_name, email, is_email_valid, phone, city, country, signup_date, status, gender)
select
  customer_id, full_name, email, is_email_valid, phone, city, country, signup_date, status, gender
from cleaned
on conflict (customer_id) do update set
  full_name      = excluded.full_name,
  email          = excluded.email,
  is_email_valid = excluded.is_email_valid,
  phone          = excluded.phone,
  city           = excluded.city,
  country        = excluded.country,
  signup_date    = excluded.signup_date,
  status         = excluded.status,
  gender         = excluded.gender,
  loaded_at      = now();

-- ---------------------------------------------------------------------------
-- PRODUCTS
-- ---------------------------------------------------------------------------
with src as (
  select
    upper(btrim(productid))           as product_id,
    btrim(productname)                as product_name,
    btrim(coalesce(category, ''))     as category,
    public.parse_price(unitprice)     as unit_price,
    btrim(coalesce(currency, ''))     as currency,
    btrim(coalesce(stock, ''))        as stock,
    public.safe_date(updatedat)       as updated_at,
    _loaded_at
  from public.stg_products
),
dedup as (
  select *,
         row_number() over (
           partition by product_id
           order by (unit_price is null), updated_at desc nulls last, _loaded_at desc
         ) as rn
  from src
  where product_id is not null and product_id <> ''
),
cleaned as (
  select
    product_id,
    nullif(initcap(regexp_replace(product_name, '\s+', ' ', 'g')), '') as product_name,
    case
      when lower(category) in ('electronics','electronic','điện tử','dien tu') then 'electronics'
      when lower(category) in ('phụ kiện','phu kien','linh kiện','linh kien',
                               'accessories','accessory') then 'accessories'
      else nullif(lower(category), '')
    end as category,
    unit_price,
    case
      when lower(currency) in ('','vnd','đ','₫','vnđ') then 'VND'
      when lower(currency) in ('usd','$')               then 'USD'
      when currency ~ '^[A-Za-z]{3}$'                   then upper(currency)
    end as currency,
    case when public.parse_int(stock) is not null then greatest(public.parse_int(stock), 0) end as stock,
    updated_at
  from dedup
  where rn = 1
)
insert into public.products
  (product_id, product_name, category, unit_price, currency, stock, updated_at)
select product_id, product_name, category, unit_price, currency, stock, updated_at
from cleaned
on conflict (product_id) do update set
  product_name = excluded.product_name,
  category     = excluded.category,
  unit_price   = excluded.unit_price,
  currency     = excluded.currency,
  stock        = excluded.stock,
  updated_at   = excluded.updated_at,
  loaded_at    = now();

-- ---------------------------------------------------------------------------
-- ORDERS
-- ---------------------------------------------------------------------------
with src as (
  select
    upper(btrim(orderid))              as order_id,
    upper(btrim(coalesce(customerid, ''))) as customer_id,
    upper(btrim(coalesce(productid, '')))  as product_id,
    btrim(coalesce(quantity, ''))      as qty_raw,
    public.parse_price(unitprice)      as unit_price,
    public.safe_date(orderdate)        as order_date,
    lower(btrim(coalesce(status, ''))) as st,
    lower(btrim(coalesce(paymentmethod, ''))) as pm,
    public.norm_city(shippingcity)     as shipping_city,
    _loaded_at
  from public.stg_orders
),
dedup as (
  select *,
         row_number() over (partition by order_id order by _loaded_at desc) as rn
  from src
  where order_id is not null and order_id <> ''
),
cleaned as (
  select
    order_id,
    nullif(customer_id, '') as customer_id,
    nullif(product_id, '')  as product_id,
    public.parse_int(qty_raw) as quantity,
    unit_price,
    order_date,
    case
      when st in ('done','complete','completed','đã giao','da giao','hoàn thành','hoan thanh') then 'completed'
      when st in ('shipped','shipping','đang giao','dang giao')  then 'shipped'
      when st in ('pending','chờ xử lý','cho xu ly')             then 'pending'
      when st in ('cancelled','canceled','đã hủy','da huy')      then 'cancelled'
      when st in ('','null')                                    then 'unknown'
      else st
    end as status,
    case
      when pm in ('cod','cash on delivery')                       then 'COD'
      when pm in ('credit_card','credit card','card')             then 'Credit Card'
      when pm in ('ck','bank transfer','bank_transfer','chuyển khoản','chuyen khoan') then 'Bank Transfer'
      when pm = 'momo'                                            then 'Momo'
      when pm in ('','null')                                      then 'unknown'
      else pm
    end as payment_method,
    shipping_city
  from dedup
  where rn = 1
)
insert into public.orders
  (order_id, customer_id, product_id, quantity, unit_price, order_date, status,
   payment_method, shipping_city, is_customer_valid, is_product_valid,
   is_quantity_valid, is_future_date, price_mismatch)
select
  o.order_id, o.customer_id, o.product_id, o.quantity, o.unit_price, o.order_date,
  o.status, o.payment_method, o.shipping_city,
  exists (select 1 from public.customers c where c.customer_id = o.customer_id) as is_customer_valid,
  exists (select 1 from public.products  p where p.product_id  = o.product_id)  as is_product_valid,
  (o.quantity is not null and o.quantity > 0)                                   as is_quantity_valid,
  (o.order_date is not null and o.order_date > current_date)                     as is_future_date,
  exists (select 1 from public.products p
          where p.product_id = o.product_id
            and p.unit_price is not null
            and o.unit_price is not null
            and o.unit_price <> p.unit_price)                                     as price_mismatch
from cleaned o
on conflict (order_id) do update set
  customer_id       = excluded.customer_id,
  product_id        = excluded.product_id,
  quantity          = excluded.quantity,
  unit_price        = excluded.unit_price,
  order_date        = excluded.order_date,
  status            = excluded.status,
  payment_method    = excluded.payment_method,
  shipping_city     = excluded.shipping_city,
  is_customer_valid = excluded.is_customer_valid,
  is_product_valid  = excluded.is_product_valid,
  is_quantity_valid = excluded.is_quantity_valid,
  is_future_date    = excluded.is_future_date,
  price_mismatch    = excluded.price_mismatch,
  loaded_at         = now();

-- ---------------------------------------------------------------------------
-- VIEWS KIEM TRA CHAT LUONG
-- ---------------------------------------------------------------------------
create or replace view public.v_orders_clean as
select *
from public.orders
where is_customer_valid and is_product_valid
  and is_quantity_valid and not is_future_date;

create or replace view public.v_data_quality as
  select 'customers_total'            as metric, count(*)::bigint as value from public.customers
  union all
  select 'customers_invalid_email',    count(*) from public.customers where not is_email_valid
  union all
  select 'customers_missing_phone',    count(*) from public.customers where phone is null
  union all
  select 'customers_missing_signup',   count(*) from public.customers where signup_date is null
  union all
  select 'products_total',             count(*) from public.products
  union all
  select 'products_missing_price',     count(*) from public.products where unit_price is null
  union all
  select 'orders_total',               count(*) from public.orders
  union all
  select 'orders_orphan_customer',     count(*) from public.orders where not is_customer_valid
  union all
  select 'orders_orphan_product',      count(*) from public.orders where not is_product_valid
  union all
  select 'orders_bad_quantity',        count(*) from public.orders where not is_quantity_valid
  union all
  select 'orders_future_date',         count(*) from public.orders where is_future_date
  union all
  select 'orders_price_mismatch',      count(*) from public.orders where price_mismatch;
