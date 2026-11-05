# Phụ lục: Các Component trong Apache Hop và cách sử dụng

Tài liệu bổ sung cho sách "Apache Hop" — trình bày chi tiết các component (Transform, Action, Metadata) và cách sử dụng từng thành phần trong thực tế.

---

## Chương 15. Tổng quan các component trong Apache Hop

### 15.1. Component là gì?

Trong Apache Hop, **component** là các khối chức năng có sẵn để xây dựng pipeline và workflow. Thay vì viết code, người dùng kéo-thả component lên canvas, cấu hình tham số và nối chúng lại. Mỗi component thực hiện một thao tác cụ thể: đọc dữ liệu, biến đổi, ghi dữ liệu, kiểm tra điều kiện, gọi pipeline con, v.v.

### 15.2. Phân loại component

| Nhóm | Dùng trong | Vai trò |
|---|---|---|
| Transform | Pipeline | Xử lý dòng dữ liệu (đọc, biến đổi, ghi) |
| Action | Workflow | Điều phối công việc (chạy pipeline, kiểm tra file, SQL, log) |
| Metadata | Cả hai | Cấu hình dùng chung (connection, run config, logging) |

### 15.3. Cách tìm và thêm component

1. Mở pipeline/workflow trong Hop GUI.
2. Nhấn icon **+** hoặc dùng hộp tìm kiếm (Ctrl+Space / Cmd+Space).
3. Gõ tên component (tiếng Anh, ví dụ: `CSV Input`, `Filter Rows`).
4. Kéo component lên canvas.
5. Nhấp đúp để mở cấu hình.
6. Nối các component bằng hop.

### 15.4. Quy tắc đặt tên

- Đặt tên theo vai trò: `Read_Orders`, `Filter_Valid`, `Write_Staging`.
- Tránh tên mặc định như `CSV Input 2`.
- Tên transform/action xuất hiện trong log và preview, giúp debug nhanh.

---

## Chương 16. Transform Input — đọc dữ liệu

### 16.1. CSV File Input

**Chức năng:** Đọc file CSV/delimited.

**Cấu hình chính:**
- **Filename**: đường dẫn file (hỗ trợ `${VAR}`).
- **Separator**: ký tự phân cách (`,`, `;`, `\t`).
- **Enclosure**: dấu ngoặc kép (`"`).
- **Header**: dòng đầu có phải tên cột?
- **Encoding**: UTF-8, Windows-1258, ...
- **Fields**: tên, kiểu, format, length, precision.

**Cách dùng:**
1. Kéo `CSV File Input` lên canvas.
2. Nhấp đúp → nhập filename.
3. Nhấn **Get Fields** để tự động detect schema.
4. Kiểm tra kiểu dữ liệu từng cột (String, Integer, Date, ...).
5. Nối với transform tiếp theo.

**Lưu ý:**
- Nếu file có tiếng Việt, dùng encoding `UTF-8`.
- Kiểm tra delimiter: Excel xuất CSV tiếng Việt thường dùng `;`.
- Dòng cuối thiếu cột → set `Strict types` = N.

### 16.2. Excel Input

**Chức năng:** Đọc file `.xlsx` / `.xls`.

**Cấu hình chính:**
- **File**: đường dẫn file.
- **Sheets**: chọn sheet, start row, start col.
- **Header**: dòng tiêu đề.
- **Fields**: tên cột và kiểu.

**Cách dùng:**
1. Kéo `Excel Input`.
2. Nhập file path.
3. Chọn sheet (hoặc regex để đọc nhiều sheet).
4. Nhấn **Get Fields**.
5. Kiểm tra kiểu: ngày Excel lưu dạng số → Hop tự convert nếu set type `Date`.

**Lưu ý:**
- File Excel có thể chứa formula, ô trống, nhiều sheet.
- Nếu đọc từ Google Drive: dùng VFS path `googledrive:///folder/file.xlsx`.

### 16.3. Table Input

**Chức năng:** Đọc dữ liệu từ CSDL bằng SQL.

**Cấu hình chính:**
- **Connection**: chọn database connection (metadata).
- **SQL**: câu truy vấn.
- **Parameters**: tham số `${}`.

**Cách dùng:**
1. Tạo connection trong Metadata perspective.
2. Kéo `Table Input`.
3. Chọn connection, nhập SQL.
4. Nhấn **Preview** để kiểm tra.

**Ví dụ:**
```sql
SELECT order_id, customer_id, amount, order_date
FROM orders
WHERE order_date >= ${BUSINESS_DATE}
```

### 16.4. JSON Input

**Chức năng:** Đọc file JSON.

**Cấu hình chính:**
- **File**: đường dẫn JSON.
- **JSONPath**: đường dẫn đến mảng dữ liệu (`$.data[*]`).
- **Fields**: mapping field từ JSON.

**Cách dùng:**
1. Kéo `JSON Input`.
2. Nhập file path.
3. Nhập JSONPath (ví dụ `$.orders[*]`).
4. Nhấn **Get Fields**.

### 16.5. REST Client

**Chức năng:** Gọi HTTP API trong pipeline.

**Cấu hình chính:**
- **URL**: endpoint.
- **Method**: GET/POST.
- **Headers**: Authorization, Content-Type.
- **Result field**: tên field chứa response.

**Cách dùng:**
1. Kéo `REST Client`.
2. Nhập URL (có thể dùng `${VAR}`).
3. Chọn method và headers.
4. Output: response body trong field chỉ định.
5. Nối với `JSON Input` để parse response.

---

## Chương 17. Transform Output — ghi dữ liệu

### 17.1. Table Output

**Chức năng:** Ghi các dòng vào bảng CSDL.

**Cấu hình chính:**
- **Connection**: database connection.
- **Target table**: tên bảng.
- **Commit size**: số dòng commit một lần (mặc định 1000).
- **Truncate table**: xóa trước khi ghi?
- **Specify database fields**: mapping cột.

**Cách dùng:**
1. Kéo `Table Output`.
2. Chọn connection và target table.
3. Nhấn **Get Fields** → mapping tự động.
4. Đặt commit size phù hợp (1000-5000).
5. Chọn truncate nếu load full.

**Lưu ý:**
- Nếu bảng chưa tồn tại, Hop có thể tạo (tùy connection).
- Batch insert nhanh hơn insert từng dòng.
- Kiểm tra kiểu dữ liệu: Hop tự convert nếu schema khớp.

### 17.2. Text File Output

**Chức năng:** Ghi ra file văn bản (CSV, TSV, ...).

**Cấu hình chính:**
- **Filename**: đường dẫn output.
- **Separator / Enclosure**: `,` / `"`.
- **Header**: có ghi dòng tiêu đề?
- **Encoding**: UTF-8.
- **Append**: ghi thêm hay ghi đè?

### 17.3. Excel Writer

**Chức năng:** Ghi kết quả vào file Excel.

**Cấu hình chính:**
- **Filename**: file output.
- **Sheet name**: tên sheet.
- **Header**: có header?

**Lưu ý:** Nếu file đã tồn tại, cần cấu hình append/overwrite.

### 17.4. JSON Output

**Chức năng:** Xuất dữ liệu thành JSON.

**Cấu hình chính:**
- **Filename**: file output.
- **Json bloc**: tên object chứa dữ liệu.

---

## Chương 18. Transform làm sạch và chuẩn hóa

### 18.1. Select Values

**Chức năng:** Chọn, đổi tên, sắp xếp, đổi kiểu trường.

**Cách dùng:**
1. Kéo `Select Values`.
2. Tab **Select & Alter**: chọn field cần giữ, đổi tên, đổi type.
3. Tab **Remove**: bỏ field không cần.
4. Tab **Meta-data**: đổi kiểu dữ liệu.

**Ví dụ:** Đổi `customerid` → `customer_id`, `String` → `Integer`.

### 18.2. Filter Rows

**Chức năng:** Chia dòng theo điều kiện đúng/sai.

**Cấu hình chính:**
- **Condition**: biểu thức (field = value, field > 0, ...).
- **Send 'true' data to**: transform đích cho dòng đúng.
- **Send 'false' data to**: transform đích cho dòng sai.

**Cách dùng:**
1. Kéo `Filter Rows`.
2. Nhập điều kiện.
3. Nối nhánh true/false đến các transform khác.

### 18.3. If Null / Null If

**If Null:** Thay giá trị null bằng default.
**Null If:** Thay giá trị cụ thể thành null.

**Cách dùng:**
- If Null: field = `email`, value = `unknown@email.com`.
- Null If: field = `status`, value = `N/A` → null.

### 18.4. Replace in String

**Chức năng:** Tìm/thay chuỗi.

**Cách dùng:**
1. Kéo `Replace in String`.
2. Nhập field, search string, replace string.
3. Chọn use regex nếu cần.

### 18.5. Data Validator

**Chức năng:** Kiểm tra quy tắc và dữ liệu.

**Cách dùng:**
1. Kéo `Data Validator`.
2. Thêm rule: field, type, min/max, regex, not null.
3. Dòng pass → nhánh true; dòng fail → nhánh false (lỗi).

**Ví dụ rule:** `email` phải match regex `^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$`.

### 18.6. Unique Rows

**Chức năng:** Loại trùng lặp.

**Cách dùng:**
1. Kéo `Unique Rows`.
2. Chọn field(s) làm khóa.
3. Chọn **Compare all fields** hoặc chỉ khóa.
4. Dòng trùng bị loại (hoặc chuyển sang nhánh lỗi).

---

## Chương 19. Transform kết hợp và tra cứu

### 19.1. Stream Lookup

**Chức năng:** Tra cứu từ một luồng dữ liệu khác (in-memory).

**Cách dùng:**
1. Kéo `Stream Lookup`.
2. Chọn stream tra cứu (phải đã được sort).
3. Chọn khóa tra cứu (field từ main + field từ lookup).
4. Chọn field lấy về.
5. Xử lý không khớp: trả null hoặc bỏ dòng.

**Lưu ý:** Stream lookup load toàn bộ lookup stream vào memory → phù hợp bảng nhỏ.

### 19.2. Database Lookup

**Chức năng:** Tra cứu giá trị trong CSDL.

**Cách dùng:**
1. Kéo `Database Lookup`.
2. Chọn connection.
3. Nhập table/schema.
4. Chọn khóa tra cứu.
5. Chọn field lấy về.

**Lưu ý:** Mỗi dòng có thể gọi 1 query → chậm với dữ liệu lớn. Dùng cache nếu có.

### 19.3. Join Rows (Cartesian Product)

**Chức năng:** Kết hợp dòng từ các luồng (mọi tổ hợp).

**Cách dùng:**
1. Kéo `Join Rows`.
2. Nối 2+ input streams.
3. Hop sẽ tạo cartesian product.

**Lưu ý:** Dữ liệu lớn → bùng nổ số dòng. Dùng cẩn thận.

### 19.4. Merge Join

**Chức năng:** Kết hợp dữ liệu đã sort.

**Cách dùng:**
1. Sort cả 2 stream theo khóa join (dùng `Sort Rows`).
2. Kéo `Merge Join`.
3. Chọn join type (Inner, Left, Right, Full).
4. Chọn khóa join.

**Lưu ý:** Input phải đã sort theo khóa join.

### 19.5. Append Streams

**Chức năng:** Nối các luồng (union all).

**Cách dùng:**
1. Kéo `Append Streams`.
2. Nối các stream có schema tương thích.
3. Output: tất cả dòng từ các stream.

---

## Chương 20. Transform tổng hợp và sắp xếp

### 20.1. Group By

**Chức năng:** Gom nhóm và tính tổng hợp.

**Cách dùng:**
1. Kéo `Group By`.
2. Tab **Group fields**: chọn field làm khóa group.
3. Tab **Aggregates**: chọn hàm (Sum, Count, Min, Max, Average, ...).
4. Output: 1 dòng per group.

**Ví dụ:** Group by `customer_id`, aggregate `sum(amount)`, `count(order_id)`.

### 20.2. Sort Rows

**Chức năng:** Sắp xếp dòng.

**Cách dùng:**
1. Kéo `Sort Rows`.
2. Chọn field sort, direction (asc/desc).
3. **Only pass unique rows**: loại trùng (tùy chọn).

**Lưu ý:** Sort tốn memory với dữ liệu lớn. Có thể dùng external sort.

### 20.3. Unique Rows

**Chức năng:** Loại trùng lặp.

**Cách dùng:**
1. Kéo `Unique Rows`.
2. Chọn field(s) làm khóa.
3. Chọn **Compare all fields** hoặc chỉ khóa.

---

## Chương 21. Transform điều khiển và tiện ích

### 21.1. Row Generator

**Chức năng:** Tạo dòng dữ liệu thử (không đọc nguồn).

**Cách dùng:**
1. Kéo `Row Generator`.
2. Đặt số dòng (limit).
3. Thêm field với giá trị constant.

**Dùng cho:** Test pipeline, tạo dữ liệu mẫu.

### 21.2. Get Variables

**Chức năng:** Lấy giá trị biến Hop vào field.

**Cách dùng:**
1. Kéo `Get Variables`.
2. Thêm mapping: variable name → field name → type.

**Ví dụ:** `${BUSINESS_DATE}` → field `business_date` (Date).

### 21.3. Set field value to a constant

**Chức năng:** Đặt giá trị constant cho field.

**Cách dùng:**
1. Kéo transform.
2. Chọn field, nhập value.

### 21.4. Write to Log

**Chức năng:** Ghi log thông tin.

**Cách dùng:**
1. Kéo `Write to Log`.
2. Chọn field cần log.
3. Set log level (Basic, Detailed, ...).

### 21.5. Pipeline Executor

**Chức năng:** Gọi pipeline con từ pipeline cha.

**Cách dùng:**
1. Kéo `Pipeline Executor`.
2. Chọn pipeline con.
3. Mapping parameters từ cha → con.
4. Cấu hình batch size, concurrency.

### 21.6. Workflow Executor

**Chức năng:** Gọi workflow con từ pipeline.

**Cách dùng:**
1. Kéo `Workflow Executor`.
2. Chọn workflow con.
3. Mapping parameters.

---

## Chương 22. Action trong Workflow và cách dùng

### 22.1. Start

**Mục đích:** Điểm bắt đầu của workflow.

**Cách dùng:** Luôn có 1 action Start. Nối từ Start đến action đầu tiên.

### 22.2. Pipeline

**Mục đích:** Chạy một pipeline.

**Cách dùng:**
1. Kéo action `Pipeline`.
2. Chọn pipeline file (.hpl).
3. Chọn run configuration.
4. Set **Wait until finished** = Y (chờ pipeline xong mới chạy tiếp).

### 22.3. SQL

**Mục đích:** Thực thi SQL.

**Cách dùng:**
1. Kéo action `SQL`.
2. Chọn connection.
3. Nhập SQL trực tiếp hoặc chọn file `.sql`.
4. Set **Send one statement** = Y (chạy toàn bộ file như 1 statement).

### 22.4. File exists / Checks if files exists

**Mục đích:** Kiểm tra file tồn tại.

**Cách dùng:**
1. Kéo action.
2. Nhập filename (hỗ trợ `${VAR}`).
3. Nhánh true: file có; nhánh false: file không có.

### 22.5. Copy / Move / Delete file

**Mục đích:** Thao tác file.

**Cách dùng:**
1. Kéo action tương ứng.
2. Nhập source, destination, wildcard.

### 22.6. Write to Log

**Mục đích:** Ghi log.

**Cách dùng:**
1. Kéo `Write to Log`.
2. Nhập message (hỗ trợ `${VAR}`).

### 22.7. Mail

**Mục đích:** Gửi email.

**Cách dùng:**
1. Kéo `Mail`.
2. Cấu hình SMTP server, from, to, subject, body.

### 22.8. Success / Abort

- **Success:** kết thúc workflow thành công.
- **Abort:** dừng workflow và báo lỗi.

### 22.9. Shell (Execute a process)

**Mục đích:** Chạy lệnh shell/external process.

**Cách dùng:**
1. Kéo action `Shell` (hoặc `Execute a process`).
2. Nhập filename (script) hoặc insert script trực tiếp.
3. Set work directory.
4. Hop capture stdout/stderr.

**Ví dụ:** Gọi `python3 scripts/clean.py` từ workflow.

---

## Chương 23. Metadata components

### 23.1. Database Connection

**Chức năng:** Cấu hình kết nối CSDL dùng chung.

**Cách tạo:**
1. Perspective → Metadata.
2. Chuột phải **Database Connection** → New.
3. Chọn database type (PostgreSQL, MySQL, ...).
4. Nhập host, port, database, username, password.
5. Nhấn **Test** để kiểm tra.

**Lưu ý:** Dùng `${VAR}` cho host/password để tách môi trường.

### 23.2. Pipeline Run Configuration

**Chức năng:** Cấu hình cách chạy pipeline (engine, parallelism).

**Cách tạo:**
1. Metadata → Pipeline Run Configuration → New.
2. Chọn engine: Local, Remote, Beam Direct/Spark/Flink.
3. Đặt tên (ví dụ: `local`).

### 23.3. Workflow Run Configuration

**Chức năng:** Cấu hình cách chạy workflow.

**Cách tạo:**
1. Metadata → Workflow Run Configuration → New.
2. Chọn engine: Local, Remote.

### 23.4. Logging Configuration

**Chức năng:** Cấu hình vị trí lưu log thực thi.

**Cách tạo:**
1. Metadata → Logging → New.
2. Chọn location (local folder, database, ...).
3. Set root folder cho audit.

### 23.5. Variables / Environment

**Chức năng:** Định nghĩa biến và môi trường.

**Cách dùng:**
1. Project config → Variables.
2. Thêm variable name + value.
3. Environment: tạo file env với giá trị theo môi trường (DEV/PROD).

---

## Chương 24. Plugin và mở rộng

### 24.1. Plugin là gì?

Hop dùng kiến trúc plugin. Mỗi transform, action, database driver, VFS provider là một plugin. Plugin nằm trong thư mục `plugins/` của Hop.

### 24.2. Cài đặt plugin

1. Tải plugin jar.
2. Đặt vào `plugins/transforms/` hoặc `plugins/actions/` hoặc `plugins/databases/`.
3. Restart Hop GUI.

### 24.3. Plugin thường dùng

| Plugin | Mục đích |
|---|---|
| Google Drive VFS | Đọc/ghi file trên Google Drive |
| PostgreSQL | Kết nối PostgreSQL |
| JSON | Đọc/ghi JSON |
| REST Client | Gọi HTTP API |

### 24.4. Kiểm tra plugin đã load

- Mở Hop GUI → palette transform/action → tìm tên.
- Nếu không thấy, kiểm tra phiên bản Hop và plugin compatibility.

---

## Chương 25. Ví dụ thực hành: ETL Excel/CSV → Database

### 25.1. Mục tiêu

Đọc file Excel (3 sheet: customers, products, orders) → làm sạch → ghi vào PostgreSQL.

### 25.2. Các bước

1. **Tạo project** `etl_demo` với thư mục `pipelines/`, `workflows/`, `sql/`, `metadata/`.
2. **Tạo connection** `supabase` (PostgreSQL) trong Metadata.
3. **Tạo pipeline** `01_load_staging.hpl`:
   - `Excel Input` (3 nhánh, 1 per sheet) → `Table Output` (stg_customers, stg_products, stg_orders).
4. **Tạo SQL** `02_clean.sql`: dedupe, normalize, validate, upsert.
5. **Tạo workflow** `etl.hwf`:
   - Start → Init schema (SQL) → Load staging (Pipeline) → Clean (SQL/Python) → Success.
6. **Chạy thử** với dữ liệu nhỏ, kiểm tra log.

### 25.3. Checklist

- [ ] Connection test OK.
- [ ] Pipeline preview đúng schema.
- [ ] Workflow chạy thành công.
- [ ] Số dòng đọc/ghi khớp.
- [ ] Dữ liệu đích đúng kỳ vọng.

---

## Chương 26. Ví dụ thực hành: Workflow với nhánh lỗi

### 26.1. Mục tiêu

Khi pipeline thất bại, ghi log và gửi thông báo, không chạy bước tiếp.

### 26.2. Cấu trúc

```
Start
  └─► Init schema ──fail──► Log failure ──► Abort
        │success
        ▼
  Load staging ──fail──► Log failure ──► Abort
        │success
        ▼
  Clean ──fail──► Log failure ──► Abort
        │success
        ▼
  Success
```

### 26.3. Cách làm

1. Tạo action `Start`.
2. Tạo action `Pipeline` (chạy pipeline chính).
3. Nối Start → Pipeline (evaluation=Y, unconditional=Y).
4. Tạo action `Log failure` (SQL hoặc Write to Log).
5. Nối Pipeline → Log failure (evaluation=N).
6. Tạo action `Abort`.
7. Nối Log failure → Abort (evaluation=Y, unconditional=Y).
8. Tạo action `Success`.
9. Nối Pipeline → Success (evaluation=Y).

---

## Chương 27. Best practices

### 27.1. Thiết kế

- Đặt tên component theo vai trò.
- Giữ schema rõ ràng, loại cột thừa sớm.
- Tách bước chuẩn hóa, kiểm tra, ghi đích.
- Dùng biến/metadata, tránh hardcode.
- Một pipeline = một trách nhiệm.

### 27.2. Vận hành

- Luôn lưu file trước khi chạy.
- Chạy thử với dữ liệu nhỏ.
- Kiểm tra số dòng đọc/ghi/lỗi.
- Có nhánh lỗi và logging.
- Xác định chiến lược rerun (upsert/staging).
- Không commit secret vào Git.

### 27.3. Debug

- Bắt đầu từ thông báo lỗi đầu tiên.
- Kiểm tra schema, null, định dạng ngày/số.
- Chạy với ít dòng để tái hiện.
- Dùng preview để kiểm tra dữ liệu trung gian.
- Ghi log đủ context (run id, tên đối tượng, số dòng).

### 27.4. Checklist trước khi production

- [ ] Connection test OK.
- [ ] Biến/metadata đúng môi trường.
- [ ] Dữ liệu đầu ra đúng kỳ vọng.
- [ ] Rerun không trùng dữ liệu.
- [ ] Có nhánh lỗi và thông báo.
- [ ] Log đủ để debug.
- [ ] File/config không chứa secret.
- [ ] Tài liệu vận hành đầy đủ.
EOF
echo "written"