### etl_GDT read API

Flask API đọc dữ liệu đã ETL trong Supabase Postgres. Dùng để hệ thống khác lấy dữ liệu qua HTTP/JSON.

#### Chạy

```bash
# cách 1: script (khuyến nghị)
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/run-api.sh

# chạy nền
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/run-api.sh --daemon
/Users/minhduc/Documents/WorkSpace/etl_GDT_tools/bin/stop-api.sh

# cách 2: python trực tiếp
python3 api/app.py
```

Mặc định: `http://127.0.0.1:8000`

Đổi host/port trong `.env`:
```env
API_HOST=0.0.0.0
API_PORT=8000
# API_KEY=secret           # nếu đặt, client phải gửi header X-API-Key
```

#### Endpoints

| Method | Path | Mô tả |
|---|---|---|
| GET | `/` | danh sách endpoint |
| GET | `/health` | kiểm tra API + DB |
| GET | `/api/v1/summary` | số lượng customers/products/orders, doanh thu, run gần nhất |
| GET | `/api/v1/customers` | danh sách khách hàng (`limit`, `offset`, `q`, `status`, `country`) |
| GET | `/api/v1/customers/<id>` | 1 khách hàng + 100 đơn gần nhất |
| GET | `/api/v1/products` | danh sách sản phẩm (`limit`, `offset`, `q`, `category`, `currency`) |
| GET | `/api/v1/products/<id>` | 1 sản phẩm + 100 đơn gần nhất |
| GET | `/api/v1/orders` | đơn hàng (`limit`, `offset`, `customer_id`, `product_id`, `status`, `from`, `to`) |
| GET | `/api/v1/orders/<id>` | 1 đơn + thông tin khách + sản phẩm |
| GET | `/api/v1/order-details` | join orders + customers + products (`q`, `status`, `customer_id`, `product_id`, `from`, `to`) |
| GET | `/api/v1/etl/runs` | lịch sử chạy ETL (`limit`, `offset`) |

Phân trang mặc định `limit=50`, tối đa `200`. Response dạng:

```json
{
  "data": [ ... ],
  "meta": {"limit": 50, "offset": 0, "count": 50, "total": 70}
}
```

#### Ví dụ

```bash
curl http://127.0.0.1:8000/health
curl "http://127.0.0.1:8000/api/v1/summary"
curl "http://127.0.0.1:8000/api/v1/customers?limit=5&q=nguyen"
curl "http://127.0.0.1:8000/api/v1/orders?status=completed&from=2024-01-01"
curl "http://127.0.0.1:8000/api/v1/order-details?limit=10"
curl "http://127.0.0.1:8000/api/v1/etl/runs?limit=5"
```

Nếu đặt `API_KEY`:
```bash
curl -H "X-API-Key: secret" http://127.0.0.1:8000/api/v1/summary
```

#### API key

Bật/tắt trong `.env`:
```env
API_KEY=eff6d90857c9cf57e0f06ca7c6fdf314497898ba8f47e601e4696e80c0ef3b3a
```

- Tất cả endpoint `/api/v1/*` yêu cầu header `X-API-Key`.
- `/` và `/health` vẫn công khai (dùng cho health check).
- Sai/thiếu key → `401 {"error":"unauthorized","hint":"send X-API-Key"}`.
- Đổi key: sửa `API_KEY` trong `.env` rồi chạy lại `stop-api.sh` + `run-api.sh --daemon`.
- Tạo key mới: `openssl rand -hex 32`.
- Để trống `API_KEY=` nếu muốn tắt xác thực (chỉ nên làm khi chạy localhost).

#### Test bằng Postman

1. Mở Postman → **Import** → chọn file `api/etl_gdt.postman_collection.json`.
2. Chọn collection **etl_GDT API** → tab **Variables**:
   - `baseUrl` = `http://127.0.0.1:8000`
   - `apiKey` = key trong `.env` (xem bằng `grep '^API_KEY=' .env`)
3. Chọn từng request → **Send**.
4. Query params nằm ở tab **Params**, header `X-API-Key: {{apiKey}}` đã có sẵn ở tab **Headers**.
5. Request **11 - Auth check** cố tình gửi key sai → phải trả `401`.

Thứ tự test gợi ý:

| # | Request | Kỳ vọng |
|---|---|---|
| 00 | Health | `200`, `database: up` |
| 02 | Summary | `200`, có `counts` + `last_run` |
| 03 | Customers | `200`, có `data` + `meta.total` |
| 04 | Customer detail | `200`, có `orders` |
| 07 | Orders | `200`, lọc theo `status` |
| 09 | Order details | `200`, có `customer_name` + `product_name` |
| 10 | ETL runs | `200`, có lịch sử chạy |
| 11 | Wrong key | `401`, `error: unauthorized` |

Lỗi thường gặp:
- `401` → chưa điền `apiKey` hoặc key sai.
- `Connection refused` → API chưa chạy: `run-api.sh --daemon`.
- `404` → sai `customer_id` / `product_id` / `order_id`.

