#!/usr/bin/env python3
"""etl_GDT read API  -  Flask + psycopg2 over Supabase Postgres.

Run locally:
    python3 api/app.py
    # or
    /Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/run-api.sh

Swagger-like index:
    GET http://127.0.0.1:8000/

Endpoints:
    GET /health
    GET /api/v1/summary
    GET /api/v1/customers
    GET /api/v1/customers/<customer_id>
    GET /api/v1/products
    GET /api/v1/products/<product_id>
    GET /api/v1/orders
    GET /api/v1/orders/<order_id>
    GET /api/v1/order-details          (orders + customers + products)
    GET /api/v1/etl/runs
"""
from __future__ import annotations

import atexit
import hmac
import os
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from uuid import UUID

import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask.json.provider import DefaultJSONProvider
from werkzeug.exceptions import HTTPException

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

DB_CONFIG = {
    "host": os.getenv("SUPABASE_HOST", ""),
    "port": int(os.getenv("SUPABASE_PORT", "5432")),
    "dbname": os.getenv("SUPABASE_DB", "postgres"),
    "user": os.getenv("SUPABASE_USER", ""),
    "password": os.getenv("SUPABASE_PASSWORD", ""),
    "sslmode": os.getenv("SUPABASE_SSLMODE", "require"),
    "connect_timeout": 10,
}

API_KEY = os.getenv("API_KEY", "").strip()

# ---------------------------------------------------------------------------
# DB pool + helpers
# ---------------------------------------------------------------------------
_pool: pool.ThreadedConnectionPool | None = None


def get_pool() -> pool.ThreadedConnectionPool:
    global _pool
    if _pool is None:
        missing = [k for k in ("host", "user", "password") if not DB_CONFIG.get(k)]
        if missing:
            raise RuntimeError(f"Missing Supabase env vars: {', '.join(missing)}")
        _pool = pool.ThreadedConnectionPool(1, 10, **DB_CONFIG)
    return _pool


def query(sql: str, params: tuple = ()) -> list[dict]:
    p = get_pool()
    conn = p.getconn()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = [dict(r) for r in cur.fetchall()]
        p.putconn(conn)
        return rows
    except Exception:
        p.putconn(conn, close=True)
        raise


def one(sql: str, params: tuple = ()) -> dict | None:
    rows = query(sql, params)
    return rows[0] if rows else None


def paging() -> tuple[int, int]:
    try:
        limit = int(request.args.get("limit", 50))
    except ValueError:
        limit = 50
    try:
        offset = int(request.args.get("offset", 0))
    except ValueError:
        offset = 0
    return max(1, min(limit, 200)), max(0, offset)


def list_response(rows: list[dict], limit: int, offset: int, total: int):
    return jsonify(
        {
            "data": rows,
            "meta": {
                "limit": limit,
                "offset": offset,
                "count": len(rows),
                "total": total,
            },
        }
    )


def paginate(base_select: str, base_count: str, params: list, order_by: str):
    limit, offset = paging()
    rows = query(
        f"{base_select} order by {order_by} limit %s offset %s",
        (*params, limit, offset),
    )
    total_row = one(base_count, tuple(params))
    total = int(total_row["count"]) if total_row else 0
    return list_response(rows, limit, offset, total)


# ---------------------------------------------------------------------------
# Flask app + JSON provider (dates, Decimal, UUID)
# ---------------------------------------------------------------------------
class JSONProvider(DefaultJSONProvider):
    @staticmethod
    def default(o):
        if isinstance(o, (datetime, date)):
            return o.isoformat()
        if isinstance(o, Decimal):
            return float(o)
        if isinstance(o, UUID):
            return str(o)
        return DefaultJSONProvider.default(o)


app = Flask(__name__)
app.json = JSONProvider(app)


@app.after_request
def _cors(resp):
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, X-API-Key"
    resp.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    return resp


@app.before_request
def _auth():
    if request.method == "OPTIONS":
        return ("", 204)
    if API_KEY and request.path.startswith("/api/"):
        supplied = request.headers.get("X-API-Key", "")
        if not hmac.compare_digest(supplied, API_KEY):
            return jsonify({"error": "unauthorized", "hint": "send X-API-Key"}), 401
    return None


# ---------------------------------------------------------------------------
# Root + health
# ---------------------------------------------------------------------------
@app.get("/")
def index():
    return jsonify(
        {
            "service": "etl_gdt-api",
            "version": "1.0",
            "database": "supabase/postgres",
            "endpoints": [
                "GET /health",
                "GET /api/v1/summary",
                "GET /api/v1/customers?limit=50&offset=0&q=&status=&country=",
                "GET /api/v1/customers/<customer_id>",
                "GET /api/v1/products?limit=50&offset=0&q=&category=&currency=",
                "GET /api/v1/products/<product_id>",
                "GET /api/v1/orders?limit=50&offset=0&customer_id=&product_id=&status=&from=&to=",
                "GET /api/v1/orders/<order_id>",
                "GET /api/v1/order-details?limit=50&offset=0&q=&status=&customer_id=&product_id=&from=&to=",
                "GET /api/v1/etl/runs?limit=20&offset=0",
            ],
        }
    )


@app.get("/health")
def health():
    try:
        one("select 1 as ok")
        return jsonify({"status": "ok", "database": "up"})
    except Exception as exc:
        return jsonify({"status": "error", "database": "down", "error": str(exc)}), 503


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
@app.get("/api/v1/summary")
def summary():
    counts = one(
        """
        select
          (select count(*) from public.customers) as customers,
          (select count(*) from public.products) as products,
          (select count(*) from public.orders) as orders,
          (select coalesce(sum(line_total), 0) from public.orders) as revenue,
          (select count(*) from public.orders
             where is_customer_valid = false
                or is_product_valid = false
                or is_quantity_valid = false
                or is_future_date = true
                or price_mismatch = true) as flagged_orders
        """
    )
    last_run = one(
        """
        select run_id, batch_id, pipeline_name, started_at, finished_at, status,
               rows_read, rows_written, rows_rejected, error_message, triggered_by
          from public.etl_run_log
         order by run_id desc
         limit 1
        """
    )
    return jsonify({"counts": counts, "last_run": last_run})


# ---------------------------------------------------------------------------
# Customers
# ---------------------------------------------------------------------------
CUSTOMER_COLS = """
    customer_id, full_name, email, is_email_valid, phone, city, country,
    signup_date, status, gender, loaded_at
"""


@app.get("/api/v1/customers")
def customers():
    where, params = [], []
    q = request.args.get("q", "").strip()
    if q:
        where.append("(customer_id ilike %s or full_name ilike %s or email ilike %s)")
        params += [f"%{q}%"] * 3
    if status := request.args.get("status"):
        where.append("status = %s")
        params.append(status)
    if country := request.args.get("country"):
        where.append("country = %s")
        params.append(country.upper())

    clause = (" where " + " and ".join(where)) if where else ""
    base = f"select {CUSTOMER_COLS} from public.customers{clause}"
    count = f"select count(*) as count from public.customers{clause}"
    return paginate(base, count, params, "customer_id")


@app.get("/api/v1/customers/<customer_id>")
def customer(customer_id: str):
    row = one(
        f"select {CUSTOMER_COLS} from public.customers where customer_id = %s",
        (customer_id,),
    )
    if not row:
        return jsonify({"error": "not_found", "customer_id": customer_id}), 404
    orders = query(
        """
        select order_id, order_date, status, quantity, unit_price, line_total
          from public.orders
         where customer_id = %s
         order by order_date desc nulls last
         limit 100
        """,
        (customer_id,),
    )
    return jsonify({**row, "orders": orders})


# ---------------------------------------------------------------------------
# Products
# ---------------------------------------------------------------------------
PRODUCT_COLS = """
    product_id, product_name, category, unit_price, currency, stock,
    updated_at, loaded_at
"""


@app.get("/api/v1/products")
def products():
    where, params = [], []
    q = request.args.get("q", "").strip()
    if q:
        where.append("(product_id ilike %s or product_name ilike %s)")
        params += [f"%{q}%"] * 2
    if category := request.args.get("category"):
        where.append("category = %s")
        params.append(category)
    if currency := request.args.get("currency"):
        where.append("currency = %s")
        params.append(currency.upper())

    clause = (" where " + " and ".join(where)) if where else ""
    base = f"select {PRODUCT_COLS} from public.products{clause}"
    count = f"select count(*) as count from public.products{clause}"
    return paginate(base, count, params, "product_id")


@app.get("/api/v1/products/<product_id>")
def product(product_id: str):
    row = one(
        f"select {PRODUCT_COLS} from public.products where product_id = %s",
        (product_id,),
    )
    if not row:
        return jsonify({"error": "not_found", "product_id": product_id}), 404
    orders = query(
        """
        select order_id, order_date, status, quantity, unit_price, line_total
          from public.orders
         where product_id = %s
         order by order_date desc nulls last
         limit 100
        """,
        (product_id,),
    )
    return jsonify({**row, "orders": orders})


# ---------------------------------------------------------------------------
# Orders
# ---------------------------------------------------------------------------
ORDER_COLS = """
    order_id, customer_id, product_id, quantity, unit_price, line_total,
    order_date, status, payment_method, shipping_city,
    is_customer_valid, is_product_valid, is_quantity_valid, is_future_date,
    price_mismatch, loaded_at
"""


def _order_filters() -> tuple[str, list]:
    where, params = [], []
    if customer_id := request.args.get("customer_id"):
        where.append("o.customer_id = %s")
        params.append(customer_id)
    if product_id := request.args.get("product_id"):
        where.append("o.product_id = %s")
        params.append(product_id)
    if status := request.args.get("status"):
        where.append("o.status = %s")
        params.append(status)
    if date_from := request.args.get("from"):
        where.append("o.order_date >= %s")
        params.append(date_from)
    if date_to := request.args.get("to"):
        where.append("o.order_date <= %s")
        params.append(date_to)
    clause = (" where " + " and ".join(where)) if where else ""
    return clause, params


@app.get("/api/v1/orders")
def orders():
    clause, params = _order_filters()
    base = f"select {ORDER_COLS} from public.orders o{clause}"
    count = f"select count(*) as count from public.orders o{clause}"
    return paginate(base, count, params, "o.order_date desc nulls last, o.order_id")


@app.get("/api/v1/orders/<order_id>")
def order(order_id: str):
    row = one(
        """
        select o.*,
               c.full_name as customer_name,
               c.email     as customer_email,
               c.city      as customer_city,
               p.product_name,
               p.category
          from public.orders o
          left join public.customers c on c.customer_id = o.customer_id
          left join public.products  p on p.product_id  = o.product_id
         where o.order_id = %s
        """,
        (order_id,),
    )
    if not row:
        return jsonify({"error": "not_found", "order_id": order_id}), 404
    return jsonify(row)


@app.get("/api/v1/order-details")
def order_details():
    where, params = [], []
    q = request.args.get("q", "").strip()
    if q:
        where.append(
            "(o.order_id ilike %s or c.full_name ilike %s or p.product_name ilike %s)"
        )
        params += [f"%{q}%"] * 3
    if customer_id := request.args.get("customer_id"):
        where.append("o.customer_id = %s")
        params.append(customer_id)
    if product_id := request.args.get("product_id"):
        where.append("o.product_id = %s")
        params.append(product_id)
    if status := request.args.get("status"):
        where.append("o.status = %s")
        params.append(status)
    if date_from := request.args.get("from"):
        where.append("o.order_date >= %s")
        params.append(date_from)
    if date_to := request.args.get("to"):
        where.append("o.order_date <= %s")
        params.append(date_to)

    clause = (" where " + " and ".join(where)) if where else ""
    base = f"""
        select o.order_id, o.order_date, o.status, o.quantity, o.unit_price,
               o.line_total, o.payment_method, o.shipping_city,
               o.customer_id, c.full_name as customer_name, c.email as customer_email,
               c.city as customer_city,
               o.product_id, p.product_name, p.category as product_category,
               p.currency
          from public.orders o
          left join public.customers c on c.customer_id = o.customer_id
          left join public.products  p on p.product_id  = o.product_id
          {clause}
    """
    count = f"""
        select count(*) as count
          from public.orders o
          left join public.customers c on c.customer_id = o.customer_id
          left join public.products  p on p.product_id  = o.product_id
          {clause}
    """
    return paginate(
        base, count, params, "o.order_date desc nulls last, o.order_id"
    )


# ---------------------------------------------------------------------------
# ETL run log
# ---------------------------------------------------------------------------
@app.get("/api/v1/etl/runs")
def etl_runs():
    limit, offset = paging()
    rows = query(
        """
        select run_id, batch_id, pipeline_name, started_at, finished_at, status,
               rows_read, rows_written, rows_rejected, error_message, host,
               triggered_by
          from public.etl_run_log
         order by run_id desc
         limit %s offset %s
        """,
        (limit, offset),
    )
    total_row = one("select count(*) as count from public.etl_run_log")
    total = int(total_row["count"]) if total_row else 0
    return list_response(rows, limit, offset, total)


# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------
@app.errorhandler(404)
def _not_found(exc):
    return jsonify({"error": "not_found", "path": request.path}), 404


@app.errorhandler(405)
def _method_not_allowed(exc):
    return jsonify({"error": "method_not_allowed", "method": request.method}), 405


@app.errorhandler(Exception)
def _handle(exc):
    if isinstance(exc, HTTPException):
        return jsonify({"error": exc.name.lower().replace(" ", "_"), "message": exc.description}), exc.code
    app.logger.exception("unhandled API error")
    return jsonify({"error": "internal_error", "message": str(exc)}), 500


def _cleanup():
    if _pool is not None:
        try:
            _pool.closeall()
        except Exception:
            pass


atexit.register(_cleanup)


if __name__ == "__main__":
    host = os.getenv("API_HOST", "127.0.0.1")
    port = int(os.getenv("API_PORT", "8000"))
    app.run(host=host, port=port, debug=False, use_reloader=False)
