/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates the 'gold' schema views that make up the star schema for analysis and reporting. 
	The Gold layer sits on top of Silver and contains only views.

    Naming and structure follow naming_conventions.md:
    - Dimension views use the 'dim_' prefix; fact views use the 'fact_' prefix.
    - Surrogate keys use the '<table_name>_key' suffix.
    - Names are business-friendly, not source-system names.

Design Notes:
    - Surrogate keys are generated via ROW_NUMBER() OVER (ORDER BY <natural_key>) rather than SERIAL, since views have no stored sequence. 
	  Keys are deterministic (stable across queries) as long as the underlying natural key ordering doesn't change.
    - olist_orders has no separate dim_orders — its columns (order_status, and the four order/delivery dates) are denormalized directly into fact_order_items, fact_payments, and fact_reviews. 
    - fact_order_items, fact_payments, and fact_reviews are kept as three separate fact tables rather than merged into one, since they sit at different grains (order item, payment, review)
    - product_category_name / product_category_name_english NULLs (610 rows, confirmed incomplete source records) are replaced with 'Uncategorized' in dim_products
    - dwh_data_quality_flag from silver.olist_orders is carried into fact_order_items, so downstream consumers can choose to include or exclude the flagged rows.
    - silver.olist_geolocation is deliberately excluded from the Gold layer as dim_customers and dim_sellers already carry city/state directly, 
	  which covers the business questions this project targets (sales, delivery performance, reviews by region)

Load Order (dependency-driven, since fact views reference dimension views):
    1. dim_customers, dim_sellers, dim_products, dim_date (any order)
    2. fact_order_items, fact_payments, fact_reviews (depend on the above)
===============================================================================
*/


-- dim_customers
-- Straight pull from silver.olist_customers
CREATE OR REPLACE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM silver.olist_customers;


-- dim_sellers
-- Straight pull from silver.olist_sellers. seller_city = 'Unknown' for the 2 sellers whose original city value was junk (an email address, a phone number)
CREATE OR REPLACE VIEW gold.dim_sellers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY seller_id) AS seller_key,
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM silver.olist_sellers;


-- dim_products
-- Pulls from silver.olist_products, which already resolves product_category_name_english via COALESCE fallback to the Portuguese name for untranslated categories. 
-- Both category columns additionally replace NULL (610 confirmed incomplete records) with 'Uncategorized'
CREATE OR REPLACE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY product_id) AS product_key,
    product_id,
    COALESCE(product_category_name, 'Uncategorized') AS product_category_name,
    COALESCE(product_category_name_english, 'Uncategorized') AS product_category_name_english,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM silver.olist_products;


-- dim_date
-- Generated calendar dimension, not sourced from Silver. 
-- Spans 2016-01-01 to 2018-12-31, covering the known Olist dataset window (Sep 2016 - Oct 2018) with a safety buffer. 
-- date_key uses the standard Kimball YYYYMMDD integer convention. 
-- Fact views derive a matching date_key from their own timestamp columns to join against this view.
CREATE OR REPLACE VIEW gold.dim_date AS
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT AS date_key,
    d AS full_date,
    EXTRACT(YEAR FROM d)::INT AS year,
    EXTRACT(QUARTER FROM d)::INT AS quarter,
    EXTRACT(MONTH FROM d)::INT AS month,
    TRIM(TO_CHAR(d, 'Month')) AS month_name,
    EXTRACT(DAY FROM d)::INT AS day,
    TRIM(TO_CHAR(d, 'Day')) AS day_name,
    EXTRACT(ISODOW FROM d)::INT AS day_of_week,
    EXTRACT(WEEK FROM d)::INT AS week_of_year,
    CASE WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend
FROM generate_series('2016-01-01'::DATE, '2018-12-31'::DATE, '1 day'::INTERVAL) AS d;


-- fact_order_items
-- Grain: one row per order item (order_id, order_item_id). 
-- Core fact table built from silver.olist_order_items, denormalized with order-header context from silver.olist_orders (order_status, all order/delivery dates, dwh_data_quality_flag) 
-- and surrogate keys resolved from dim_customers, dim_products, dim_sellers. order_date_key derived from order_purchase_timestamp for joining to dim_date.
CREATE OR REPLACE VIEW gold.fact_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    c.customer_key,
    p.product_key,
    s.seller_key,
    TO_CHAR(o.order_purchase_timestamp, 'YYYYMMDD')::INT AS order_date_key,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    i.shipping_limit_date,
    i.price,
    i.freight_value,
    o.dwh_data_quality_flag
FROM silver.olist_order_items i
LEFT JOIN silver.olist_orders o ON i.order_id = o.order_id
LEFT JOIN gold.dim_customers c ON o.customer_id = c.customer_id
LEFT JOIN gold.dim_products p ON i.product_id = p.product_id
LEFT JOIN gold.dim_sellers s ON i.seller_id = s.seller_id;


-- fact_payments
-- Grain: one row per payment (order_id, payment_sequential). 
-- Kept separate from fact_order_items since payments and order items sit at different grains 
-- Denormalized with order_status and order_purchase_timestamp for independent time-based analysis without requiring a join back to fact_order_items.
CREATE OR REPLACE VIEW gold.fact_payments AS
SELECT
    p.order_id,
    p.payment_sequential,
    c.customer_key,
    TO_CHAR(o.order_purchase_timestamp, 'YYYYMMDD')::INT AS order_date_key,
    p.payment_type,
    p.payment_installments,
    p.payment_value,
    o.order_status,
    o.order_purchase_timestamp
FROM silver.olist_order_payments p
LEFT JOIN silver.olist_orders o ON p.order_id = o.order_id
LEFT JOIN gold.dim_customers c ON o.customer_id = c.customer_id;


-- fact_reviews
-- Grain: one row per review (review_id, order_id) 
-- matches the composite key confirmed in Silver, since review_id alone is not unique (a single review can be linked to multiple orders). 
-- Kept separate from fact_order_items for the same grain-mismatch reason as fact_payments.
CREATE OR REPLACE VIEW gold.fact_reviews AS
SELECT
    r.review_id,
    r.order_id,
    c.customer_key,
    TO_CHAR(o.order_purchase_timestamp, 'YYYYMMDD')::INT AS order_date_key,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,
    r.review_creation_date,
    r.review_answer_timestamp,
    o.order_status,
    o.order_purchase_timestamp
FROM silver.olist_order_reviews r
LEFT JOIN silver.olist_orders o ON r.order_id = o.order_id
LEFT JOIN gold.dim_customers c ON o.customer_id = c.customer_id;
