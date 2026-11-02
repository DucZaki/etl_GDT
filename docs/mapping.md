# Mapping: source -> staging -> prod

Source: Google Drive `etl/sample_data_dirty.xlsx`, 3 sheets.
Hop Excel input reads one sheet per transform, so each sheet is a separate branch.

## customers  (43 rows incl. 3 dupes)
| Source col | Staging col | Prod col | Rule |
|---|---|---|---|
| CustomerID | customerid | customer_id | upper(trim), dedupe |
| FullName | fullname | full_name | trim, collapse spaces, initcap, strip emoji |
| Email | email | email + is_email_valid | lower(trim), regex |
| Phone | phone | phone | digits only, 84->0 |
| City | city | city | norm_city (HCM/Saigon/Ha Noi/...) |
| Country | country | country | VN/Vietnam/viet nam -> VN |
| SignupDate | signupdate | signup_date | safe_date (ISO, DD/MM, DD-MM, MM/DD) |
| Status | status | status | lower; empty -> unknown |
| Gender | gender | gender | male/female/unknown |

## products  (27 rows incl. 2 dupes)
| Source col | Staging col | Prod col | Rule |
|---|---|---|---|
| ProductID | productid | product_id | upper(trim), dedupe |
| ProductName | productname | product_name | trim, initcap |
| Category | category | category | electronics / accessories / other |
| UnitPrice | unitprice | unit_price | parse_price ($, comma, dot, negative/0 -> null) |
| Currency | currency | currency | VND/USD, vnd->VND |
| Stock | stock | stock | int >=0, non-numeric -> null |
| UpdatedAt | updatedat | updated_at | safe_date |

## orders  (73 rows incl. 3 dupes)
| Source col | Staging col | Prod col | Rule |
|---|---|---|---|
| OrderID | orderid | order_id | upper(trim), dedupe |
| CustomerID | customerid | customer_id | FK check -> is_customer_valid |
| ProductID | productid | product_id | FK check -> is_product_valid |
| Quantity | quantity | quantity | int >0 -> is_quantity_valid |
| UnitPrice | unitprice | unit_price | parse_price |
| OrderDate | orderdate | order_date | safe_date; future -> is_future_date |
| Status | status | status | completed/shipped/pending/cancelled/unknown |
| PaymentMethod | paymentmethod | payment_method | COD/Credit Card/Bank Transfer/Momo/unknown |
| ShippingCity | shippingcity | shipping_city | norm_city |

## Reject policy
Row-level: invalid rows go to `etl_rejects` with reason + raw payload. Pipeline does not abort on row errors.