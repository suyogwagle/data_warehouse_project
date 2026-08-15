/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
  This script creates tables in the 'silver' schema, dropping existing tables if they already exist. 
	Column types, constraints, and design decisions are based directly on findings from the Bronze-layer data quality checks (see quality_checks/ folder). 
	Run this script to re-define the DDL structure of 'silver' layer tables.
===============================================================================
*/


-- olist_customers
-- Bronze Layer Data Exploration findings:
-- 1. customer_id unique/no NULLs (primary key). 
-- 2. customer_city had 1 legitimate numbered locality ('quilometro 14 do mutum') hence no cleaning needed. 
-- 3. customer_state fully valid Brazilian codes
DROP TABLE IF EXISTS silver.olist_customers;
CREATE TABLE silver.olist_customers (
    customer_id               VARCHAR(50)  NOT NULL,
    customer_unique_id        VARCHAR(50)  NOT NULL,
    customer_zip_code_prefix  VARCHAR(10)  NOT NULL,
    customer_city             VARCHAR(50)  NOT NULL,
    customer_state            CHAR(2)      NOT NULL,
    dwh_create_date           TIMESTAMPTZ  DEFAULT NOW(),
    CONSTRAINT pk_silver_customers PRIMARY KEY (customer_id)
);


-- olist_geolocation
-- Bronze Layer Data Exploration findings:
-- 1. no natural single-column key; 128,178+ full-row exact duplicates confirmed (multiple delivery points share the same coordinates). Deduplicated in Silver via ROW_NUMBER, one row per zip prefix 
-- 2. geolocation_city has 32 rows with unexpected characters; 7 confirmed HTML entity/encoding corruption but others are legitimate or structural
-- 3. geolocation_state fully valid Brazilian codes.
-- 4. Resolution: 7 confirmed encoding-corrupted city values corrected via exact-match string replacement (see load_silver).
DROP TABLE IF EXISTS silver.olist_geolocation;
CREATE TABLE silver.olist_geolocation (
    geolocation_zip_code_prefix  VARCHAR(10)    NOT NULL,
    geolocation_lat              NUMERIC(10,7)  NOT NULL,
    geolocation_lng              NUMERIC(10,7)  NOT NULL,
    geolocation_city             VARCHAR(50)    NOT NULL,
    geolocation_state            CHAR(2)        NOT NULL,
    dwh_create_date              TIMESTAMPTZ    DEFAULT NOW(),
    CONSTRAINT pk_silver_geolocation PRIMARY KEY (geolocation_zip_code_prefix)
);


-- olist_order_payments
-- Bronze Layer Data Exploration findings:
-- 1. (order_id, payment_sequential) confirmed unique composite primary key, 
-- 2. no formatting mismatches. 
-- 3. payment_type: 5 valid categorical values, no unexpected entries. 
-- 4. payment_installments/payment_value: no negative values found; 
-- 5. payment_installments must be >= 1 (0 installments is invalid).
DROP TABLE IF EXISTS silver.olist_order_payments;
CREATE TABLE silver.olist_order_payments (
    order_id              VARCHAR(50)    NOT NULL,
    payment_sequential    INT            NOT NULL,
    payment_type          VARCHAR(20)    NOT NULL CHECK (payment_type IN ('credit_card','boleto','voucher','debit_card','not_defined')),
    payment_installments  INT            NOT NULL CHECK (payment_installments >= 1),
    payment_value         NUMERIC(10,2)  NOT NULL CHECK (payment_value >= 0),
    dwh_create_date       TIMESTAMPTZ    DEFAULT NOW(),
    CONSTRAINT pk_silver_order_payments PRIMARY KEY (order_id, payment_sequential)
);
 

-- olist_order_items
-- Bronze Layer Data Exploration findings:
-- 1. (order_id, order_item_id) confirmed unique composite primary key. 
-- 2. price/freight_value: no negative values, valid numeric format throughout. 
-- 3. shipping_limit_date: valid DD/MM/YYYY HH:MI format throughout.
DROP TABLE IF EXISTS silver.olist_order_items;
CREATE TABLE silver.olist_order_items (
    order_id             VARCHAR(50)    NOT NULL,
    order_item_id        INT            NOT NULL,
    product_id           VARCHAR(50)    NOT NULL,
    seller_id            VARCHAR(50)    NOT NULL,
    shipping_limit_date  TIMESTAMP      NOT NULL,
    price                NUMERIC(10,2)  NOT NULL CHECK (price >= 0),
    freight_value        NUMERIC(10,2)  NOT NULL CHECK (freight_value >= 0),
    dwh_create_date      TIMESTAMPTZ    DEFAULT NOW(),
    CONSTRAINT pk_silver_order_items PRIMARY KEY (order_id, order_item_id)
);


-- olist_order_reviews
-- Bronze Layer Data Exploration findings:
-- 1. review_id alone is NOT unique (789 duplicates, same review linked to multiple orders) 
-- 2. (review_id, order_id) is confirmed unique hence it is composite primary key. 
-- 3. review_score fully valid 1-5 range. 
-- 4. review_comment_title/message: 9,317 rows had leading/trailing spaces
-- 5. all "blank" values in review_comment_title/message confirmed to be true NULL, not empty strings 
-- 6. Both review_comment_title/message columns share the known Ã/Â encoding corruption pattern (459 rows) but left as-is since this is free text, not a joined/grouped field.
DROP TABLE IF EXISTS silver.olist_order_reviews;
CREATE TABLE silver.olist_order_reviews (
    review_id                VARCHAR(50)    NOT NULL,
    order_id                 VARCHAR(50)    NOT NULL,
    review_score             INT            NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title     VARCHAR(200),
    review_comment_message   TEXT,
    review_creation_date     TIMESTAMP      NOT NULL,
    review_answer_timestamp  TIMESTAMP      NOT NULL,
    dwh_create_date          TIMESTAMPTZ    DEFAULT NOW(),
    CONSTRAINT pk_silver_order_reviews PRIMARY KEY (review_id, order_id)
);


-- olist_orders
-- Bronze Layer Data Exploration findings:
-- 1. order_id is confirmed unique (primary key). 
-- 2. order_status: 8 valid categorical values, no unexpected entries. 
-- 3. Date columns: valid format throughout, but delivery-related dates are legitimately NULL for non-delivered orders (kept nullable). 
-- 4. Known logical inconsistencies (8 'delivered' orders with NULL delivered_customer_date; some 'canceled' orders with contradictory populated delivery dates) are genuine source data issues
-- 5. Resolution: all rows retained; the 14 inconsistent rows are flagged via dwh_data_quality_flag so downstream consumers can choose to include or exclude them (see load_silver).
DROP TABLE IF EXISTS silver.olist_orders;
CREATE TABLE silver.olist_orders (
    order_id                       VARCHAR(50)    NOT NULL,
    customer_id                    VARCHAR(50)    NOT NULL,
    order_status                   VARCHAR(20)    NOT NULL CHECK (order_status IN ('delivered','shipped','canceled','unavailable','invoiced','processing','created','approved')),
    order_purchase_timestamp       TIMESTAMP      NOT NULL,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP      NOT NULL,
    dwh_create_date                TIMESTAMPTZ    DEFAULT NOW(),
    dwh_data_quality_flag          VARCHAR(50)    DEFAULT 'valid',
    CONSTRAINT pk_silver_orders PRIMARY KEY (order_id)
);


-- olist_product_category_name_translation
-- Bronze Layer Data Exploration findings:
-- 1. product_category_name confirmed unique (primary key), no NULLs. 
-- 2. 2 rows ('eletrodomesticos_2', 'casa_conforto_2') carry a '_2' suffix, likely duplicate/re-entered categories rather than distinct ones
DROP TABLE IF EXISTS silver.olist_product_category_name_translation;
CREATE TABLE silver.olist_product_category_name_translation (
    product_category_name          VARCHAR(100)  NOT NULL,
    product_category_name_english  VARCHAR(100)  NOT NULL,
    dwh_create_date                TIMESTAMPTZ   DEFAULT NOW(),
    CONSTRAINT pk_silver_category_translation PRIMARY KEY (product_category_name)
);
 
 
-- olist_products
-- Bronze Layer Data Exploration findings:
-- 1. product_id confirmed unique (primary key). 
-- 2. 610 rows have NULL product_category_name/name_lenght/description_lenght/photos_qty (same incomplete records, confirmed) and kept nullable. 
-- 3. 2 rows NULL across all 4 dimension/weight columns (same records, confirmed) and kept nullable. 
-- 4. product_category_name: 623 rows reference 2 categories missing from the translation table
-- 5. columns renamed to fix the source 'lenght' misspelling
-- 6. Resolution: product_category_name_english resolved via LEFT JOIN to the translation table with COALESCE fallback to the original Portuguese name for the 2 untranslated categories (see load_silver).
DROP TABLE IF EXISTS silver.olist_products;
CREATE TABLE silver.olist_products (
    product_id                     VARCHAR(50)    NOT NULL,
    product_category_name          VARCHAR(100),
    product_category_name_english  VARCHAR(100),
    product_name_length            INT,
    product_description_length     INT,
    product_photos_qty             INT,
    product_weight_g               NUMERIC(10,2),
    product_length_cm              NUMERIC(10,2),
    product_height_cm              NUMERIC(10,2),
    product_width_cm               NUMERIC(10,2),
    dwh_create_date                TIMESTAMPTZ    DEFAULT NOW(),
    CONSTRAINT pk_silver_products PRIMARY KEY (product_id)
);
 
 
-- olist_sellers
-- Bronze Layer Data Exploration findings:
-- 1. seller_id confirmed unique (primary key). 
-- 2. seller_city: 24 rows with unexpected characters; mostly structural city/state/country combos, 2 genuine junk values (email, phone number), others are legitimate. 
-- 3. seller_state fully valid Brazilian codes
-- 4. Resolution: structural rows cleaned via string extraction (keep first segment before '/', ',', or '\'); the 2 junk values (email, phone number) nullified rather than treated as real cities (see load_silver).
DROP TABLE IF EXISTS silver.olist_sellers;
CREATE TABLE silver.olist_sellers (
    seller_id               VARCHAR(50)  NOT NULL,
    seller_zip_code_prefix  VARCHAR(10)  NOT NULL,
    seller_city             VARCHAR(50)  NOT NULL,
    seller_state            CHAR(2)      NOT NULL,
    dwh_create_date         TIMESTAMPTZ  DEFAULT NOW(),
    CONSTRAINT pk_silver_sellers PRIMARY KEY (seller_id)
);
