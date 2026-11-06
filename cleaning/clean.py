#!/usr/bin/env python3
"""Clean staging -> prod (replaces sql/steps/02_clean.sql). Run by Hop Shell action."""
import os, re, sys, warnings
warnings.filterwarnings('ignore')
import pandas as pd
from datetime import date
import psycopg2
from psycopg2.extras import execute_values

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
env_path = os.path.join(ROOT, ".env")
if os.path.exists(env_path):
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())

conn = psycopg2.connect(
    host=os.environ["SUPABASE_HOST"], port=os.environ["SUPABASE_PORT"],
    dbname=os.environ["SUPABASE_DB"], user=os.environ["SUPABASE_USER"],
    password=os.environ["SUPABASE_PASSWORD"], sslmode=os.environ.get("SUPABASE_SSLMODE", "require"))
conn.autocommit = False
cur = conn.cursor()

# ---------- helpers ----------
def safe_date(txt):
    if txt is None:
        return None
    s = str(txt).strip()
    if s == "":
        return None
    # try several formats
    import datetime
    fmts = ["%Y-%m-%d", "%Y/%m/%d", "%d/%m/%Y", "%d-%m-%Y", "%m/%d/%Y"]
    # handle trailing time: take first 10 chars for ISO-like
    for fmt in fmts:
        for cand in (s, s[:10]):
            try:
                return datetime.datetime.strptime(cand, fmt).date()
            except ValueError:
                continue
    return None

def parse_price(txt):
    if txt is None:
        return None
    s = str(txt).strip()
    if s == "":
        return None
    s = s.replace("$", "").replace("EUR", "").replace("eur", "").replace("₫", "").replace("đ", "").replace(" ", "")
    # both , and . : , thousands, . decimal
    if re.match(r"^-?\d{1,3}(,\d{3})+(\.\d+)?$", s):
        s = s.replace(",", "")
    elif re.match(r"^-?\d+,\d+$", s) and not re.match(r"^-?\d{1,3}(,\d{3})+$", s):
        s = s.replace(",", ".")
    elif re.match(r"^-?\d{1,3}(\.\d{3})+$", s):
        s = s.replace(".", "")
    try:
        n = float(s)
    except ValueError:
        return None
    if n <= 0:
        return None
    return round(n, 2)

def parse_int(txt):
    if txt is None:
        return None
    s = str(txt).strip().replace(",", ".")
    if not re.match(r"^-?\d+(\.0+)?$", s):
        return None
    try:
        return int(float(s))
    except ValueError:
        return None

CITY_MAP = {
    "hcm": "Ho Chi Minh", "hcm city": "Ho Chi Minh", "tp hcm": "Ho Chi Minh",
    "tphcm": "Ho Chi Minh", "ho chi minh": "Ho Chi Minh", "ho chi minh city": "Ho Chi Minh",
    "sai gon": "Ho Chi Minh", "saigon": "Ho Chi Minh", "sg": "Ho Chi Minh",
    "tp ho chi minh": "Ho Chi Minh",
    "ha noi": "Ha Noi", "hanoi": "Ha Noi", "hn": "Ha Noi", "ha noi city": "Ha Noi",
    "thu do ha noi": "Ha Noi",
    "da nang": "Da Nang", "danang": "Da Nang", "dn": "Da Nang", "đà nẵng": "Da Nang",
    "da nang city": "Da Nang",
    "hai phong": "Hai Phong", "haiphong": "Hai Phong", "hp": "Hai Phong", "hải phòng": "Hai Phong",
    "can tho": "Can Tho", "cantho": "Can Tho", "ct": "Can Tho", "cần thơ": "Can Tho",
}

def norm_city(txt):
    if txt is None:
        return None
    s = re.sub(r"\s+", " ", str(txt).strip().lower().replace(".", ""))
    if s == "":
        return None
    if s in CITY_MAP:
        return CITY_MAP[s]
    return s.title()

def norm_country(txt):
    if txt is None:
        return None
    s = str(txt).strip().lower()
    if s in ("vn", "vietnam", "viet nam", "viet-nam"):
        return "VN"
    if s in ("", "n/a", "na", "none", "null"):
        return None
    return s[:2].upper()

def norm_status(s):
    s = (s or "").strip().lower()
    if s in ("", "null"):
        return "unknown"
    mapping = {
        "done": "completed", "complete": "completed", "completed": "completed",
        "đã giao": "completed", "da giao": "completed", "hoàn thành": "completed",
        "hoan thanh": "completed",
        "shipped": "shipped", "shipping": "shipped", "đang giao": "shipped", "dang giao": "shipped",
        "pending": "pending", "chờ xử lý": "pending", "cho xu ly": "pending",
        "cancelled": "cancelled", "canceled": "cancelled", "đã hủy": "cancelled", "da huy": "cancelled",
    }
    return mapping.get(s, s)

def norm_payment(s):
    s = (s or "").strip().lower()
    mapping = {
        "cod": "COD", "cash on delivery": "COD",
        "credit_card": "Credit Card", "credit card": "Credit Card", "card": "Credit Card",
        "ck": "Bank Transfer", "bank transfer": "Bank Transfer", "bank_transfer": "Bank Transfer",
        "chuyển khoản": "Bank Transfer", "chuyen khoan": "Bank Transfer",
        "momo": "Momo",
    }
    if s in ("", "null"):
        return "unknown"
    return mapping.get(s, s)

def norm_gender(s):
    s = (s or "").strip().lower()
    if s in ("nam", "male", "m", "1"):
        return "male"
    if s in ("nữ", "nu", "female", "f", "0"):
        return "female"
    return None

def norm_category(s):
    s = (s or "").strip().lower()
    if s in ("electronics", "electronic", "điện tử", "dien tu"):
        return "electronics"
    if s in ("phụ kiện", "phu kien", "linh kiện", "linh kien", "accessories", "accessory"):
        return "accessories"
    return s if s not in ("", "null") else None

def norm_currency(s):
    s = (s or "").strip().lower()
    if s in ("", "vnd", "đ", "₫", "vnđ"):
        return "VND"
    if s in ("usd", "$"):
        return "USD"
    if len(s) == 3 and s.isalpha():
        return s.upper()
    return None

# ---------- read staging ----------
def read_table(name):
    cur.execute(f"select * from public.{name}")
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    return pd.DataFrame(rows, columns=cols)

stg_customers = read_table("stg_customers")
stg_products = read_table("stg_products")
stg_orders = read_table("stg_orders")

# ---------- customers ----------
src = pd.DataFrame({
    "customer_id": stg_customers["customerid"].astype(str).str.strip().str.upper(),
    "full_name": stg_customers["fullname"],
    "email": stg_customers["email"].fillna("").astype(str).str.strip().str.lower(),
    "phone": stg_customers["phone"].fillna("").astype(str).str.strip(),
    "city": stg_customers["city"],
    "country": stg_customers["country"],
    "signupdate": stg_customers["signupdate"],
    "status": stg_customers["status"],
    "gender": stg_customers["gender"],
    "_loaded_at": stg_customers["_loaded_at"],
})
src = src[src["customer_id"].notna() & (src["customer_id"] != "") & (src["customer_id"] != "NAN")]
# dedupe
src["_rn"] = src.groupby("customer_id")["_loaded_at"].rank(ascending=False, method="first")
# prefer non-null safe_date then latest loaded_at
def _customer_rn(g):
    g = g.copy()
    g["_sd"] = g["signupdate"].apply(lambda x: safe_date(x) is None)
    g = g.sort_values(["_sd", "_loaded_at"], ascending=[True, False])
    g["rn"] = range(1, len(g) + 1)
    return g
src = src.groupby("customer_id", group_keys=False).apply(_customer_rn)
src = src[src["rn"] == 1].copy()

src["full_name"] = src["full_name"].apply(lambda x: re.sub(r"\s+", " ", re.sub(r"[^A-Za-zÀ-ỹ0-9 .'-]", "", str(x or ""))).strip() or None)
src["full_name"] = src["full_name"].apply(lambda x: x.title() if x else None)  # initcap approx
src["email"] = src["email"].apply(lambda x: x if re.match(r"^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$", x or "") else None)
src["is_email_valid"] = src["email"].apply(lambda x: bool(x and re.match(r"^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$", x)))
def _phone(p):
    d = re.sub(r"[^0-9]", "", str(p or ""))
    if re.match(r"^84[0-9]{9}$", d):
        return "0" + d[2:]
    if len(d) in (10, 11):
        return d
    return None
src["phone"] = src["phone"].apply(_phone)
src["city"] = src["city"].apply(norm_city)
src["country"] = src["country"].apply(norm_country)
src["signup_date"] = src["signupdate"].apply(safe_date)
src["status"] = src["status"].apply(lambda x: "unknown" if str(x or "").strip().lower() in ("", "null") else str(x).strip().lower())
src["gender"] = src["gender"].apply(norm_gender)

customers_df = src[["customer_id", "full_name", "email", "is_email_valid", "phone", "city", "country", "signup_date", "status", "gender"]].copy()

# ---------- products ----------
psrc = pd.DataFrame({
    "product_id": stg_products["productid"].astype(str).str.strip().str.upper(),
    "product_name": stg_products["productname"],
    "category": stg_products["category"],
    "unit_price": stg_products["unitprice"],
    "currency": stg_products["currency"],
    "stock": stg_products["stock"],
    "updated_at": stg_products["updatedat"],
    "_loaded_at": stg_products["_loaded_at"],
})
psrc = psrc[psrc["product_id"].notna() & (psrc["product_id"] != "") & (psrc["product_id"] != "NAN")]

def _product_rn(g):
    g = g.copy()
    g["_price_null"] = g["unit_price"].apply(lambda x: parse_price(x) is None)
    g["_upd"] = g["updated_at"].apply(safe_date)
    g = g.sort_values(["_price_null", "_upd", "_loaded_at"], ascending=[True, False, False])
    g["rn"] = range(1, len(g) + 1)
    return g
psrc = psrc.groupby("product_id", group_keys=False).apply(_product_rn)
psrc = psrc[psrc["rn"] == 1].copy()

psrc["product_name"] = psrc["product_name"].apply(lambda x: re.sub(r"\s+", " ", str(x or "")).strip() or None)
psrc["product_name"] = psrc["product_name"].apply(lambda x: x.title() if x else None)
psrc["category"] = psrc["category"].apply(norm_category)
psrc["unit_price"] = psrc["unit_price"].apply(parse_price)
psrc["currency"] = psrc["currency"].apply(norm_currency)
def _stock(s):
    v = parse_int(s)
    if v is None:
        return None
    return max(v, 0)
psrc["stock"] = psrc["stock"].apply(_stock)
psrc["updated_at"] = psrc["updated_at"].apply(safe_date)

products_df = psrc[["product_id", "product_name", "category", "unit_price", "currency", "stock", "updated_at"]].copy()

# ---------- orders ----------
osrc = pd.DataFrame({
    "order_id": stg_orders["orderid"].astype(str).str.strip().str.upper(),
    "customer_id": stg_orders["customerid"].fillna("").astype(str).str.strip().str.upper(),
    "product_id": stg_orders["productid"].fillna("").astype(str).str.strip().str.upper(),
    "qty_raw": stg_orders["quantity"],
    "unit_price": stg_orders["unitprice"],
    "order_date_raw": stg_orders["orderdate"],
    "status": stg_orders["status"],
    "payment_method": stg_orders["paymentmethod"],
    "shipping_city": stg_orders["shippingcity"],
    "_loaded_at": stg_orders["_loaded_at"],
})
osrc = osrc[osrc["order_id"].notna() & (osrc["order_id"] != "") & (osrc["order_id"] != "NAN")]

# dedupe by order_id, keep latest loaded_at
osrc = osrc.sort_values("_loaded_at", ascending=False).drop_duplicates("order_id", keep="first").copy()

osrc["customer_id"] = osrc["customer_id"].apply(lambda x: x if x not in ("", "NAN") else None)
osrc["product_id"] = osrc["product_id"].apply(lambda x: x if x not in ("", "NAN") else None)
osrc["quantity"] = osrc["qty_raw"].apply(parse_int)
osrc["unit_price"] = osrc["unit_price"].apply(parse_price)
osrc["order_date"] = osrc["order_date_raw"].apply(safe_date)
osrc["status"] = osrc["status"].apply(norm_status)
osrc["payment_method"] = osrc["payment_method"].apply(norm_payment)
osrc["shipping_city"] = osrc["shipping_city"].apply(norm_city)

# validity flags
customer_ids = set(customers_df["customer_id"].dropna().tolist())
product_ids = set(products_df["product_id"].dropna().tolist())
product_price = {k: (v if pd.notna(v) else None) for k, v in zip(products_df["product_id"], products_df["unit_price"])}

osrc["is_customer_valid"] = osrc["customer_id"].apply(lambda x: x in customer_ids if x else False)
osrc["is_product_valid"] = osrc["product_id"].apply(lambda x: x in product_ids if x else False)
osrc["is_quantity_valid"] = osrc["quantity"].apply(lambda x: x is not None and x > 0)
osrc["is_future_date"] = osrc["order_date"].apply(lambda x: x is not None and x > date.today())
osrc["price_mismatch"] = osrc.apply(
    lambda r: (r["product_id"] in product_price and product_price[r["product_id"]] is not None
               and r["unit_price"] is not None and r["unit_price"] != product_price[r["product_id"]]), axis=1)

# nullify orphan ids for FK
osrc["customer_id"] = osrc.apply(lambda r: r["customer_id"] if r["is_customer_valid"] else None, axis=1)
osrc["product_id"] = osrc.apply(lambda r: r["product_id"] if r["is_product_valid"] else None, axis=1)

orders_df = osrc[["order_id", "customer_id", "product_id", "quantity", "unit_price", "order_date",
                  "status", "payment_method", "shipping_city",
                  "is_customer_valid", "is_product_valid", "is_quantity_valid", "is_future_date", "price_mismatch"]].copy()


def df_to_rows(df):
    rows = []
    for _, r in df.iterrows():
        row = []
        for v in r:
            if isinstance(v, float) and pd.isna(v):
                row.append(None)
            elif isinstance(v, pd.Timestamp):
                row.append(v.date() if pd.notna(v) else None)
            else:
                row.append(v)
        rows.append(tuple(row))
    return rows

# ---------- upsert helpers ----------
def upsert_customers(df):
    rows = df_to_rows(df)
    sql = """
    insert into public.customers
      (customer_id, full_name, email, is_email_valid, phone, city, country, signup_date, status, gender)
    values %s
    on conflict (customer_id) do update set
      full_name=excluded.full_name, email=excluded.email, is_email_valid=excluded.is_email_valid,
      phone=excluded.phone, city=excluded.city, country=excluded.country, signup_date=excluded.signup_date,
      status=excluded.status, gender=excluded.gender, loaded_at=now();
    """
    execute_values(cur, sql, rows)

def upsert_products(df):
    rows = df_to_rows(df)
    sql = """
    insert into public.products (product_id, product_name, category, unit_price, currency, stock, updated_at)
    values %s
    on conflict (product_id) do update set
      product_name=excluded.product_name, category=excluded.category, unit_price=excluded.unit_price,
      currency=excluded.currency, stock=excluded.stock, updated_at=excluded.updated_at, loaded_at=now();
    """
    execute_values(cur, sql, rows)

def upsert_orders(df):
    rows = df_to_rows(df)
    sql = """
    insert into public.orders
      (order_id, customer_id, product_id, quantity, unit_price, order_date, status, payment_method,
       shipping_city, is_customer_valid, is_product_valid, is_quantity_valid, is_future_date, price_mismatch)
    values %s
    on conflict (order_id) do update set
      customer_id=excluded.customer_id, product_id=excluded.product_id, quantity=excluded.quantity,
      unit_price=excluded.unit_price, order_date=excluded.order_date, status=excluded.status,
      payment_method=excluded.payment_method, shipping_city=excluded.shipping_city,
      is_customer_valid=excluded.is_customer_valid, is_product_valid=excluded.is_product_valid,
      is_quantity_valid=excluded.is_quantity_valid, is_future_date=excluded.is_future_date,
      price_mismatch=excluded.price_mismatch, loaded_at=now();
    """
    execute_values(cur, sql, rows)

# ---------- clean NaN -> None ----------
for _df in (customers_df, products_df, orders_df):
    _df.where(pd.notnull(_df), None, inplace=True)

# ---------- execute ----------
upsert_customers(customers_df)
upsert_products(products_df)
upsert_orders(orders_df)

# views
cur.execute("""
create or replace view public.v_orders_clean as
select * from public.orders
where is_customer_valid and is_product_valid and is_quantity_valid and not is_future_date;
""")
cur.execute("""
create or replace view public.v_data_quality as
  select 'customers_total' as metric, count(*)::bigint as value from public.customers
  union all select 'customers_invalid_email', count(*) from public.customers where not is_email_valid
  union all select 'customers_missing_phone', count(*) from public.customers where phone is null
  union all select 'customers_missing_signup', count(*) from public.customers where signup_date is null
  union all select 'products_total', count(*) from public.products
  union all select 'products_missing_price', count(*) from public.products where unit_price is null
  union all select 'orders_total', count(*) from public.orders
  union all select 'orders_orphan_customer', count(*) from public.orders where not is_customer_valid
  union all select 'orders_orphan_product', count(*) from public.orders where not is_product_valid
  union all select 'orders_bad_quantity', count(*) from public.orders where not is_quantity_valid
  union all select 'orders_future_date', count(*) from public.orders where is_future_date
  union all select 'orders_price_mismatch', count(*) from public.orders where price_mismatch;
""")

conn.commit()
print(f"customers={len(customers_df)} products={len(products_df)} orders={len(orders_df)}")
cur.close()
conn.close()
