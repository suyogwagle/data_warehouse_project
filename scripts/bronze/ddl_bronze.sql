/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema, dropping existing tables
    if they already exist. Run this script to re-define the DDL structure of 
    'bronze' layer tables for the Olist e-commerce dataset.

Source System:
    Olist Brazilian E-Commerce Public Dataset (9 source files). Expects the 
    corresponding CSVs to be available under a local 'datasets/' folder when 
    loading data (see Usage below).

Design Notes:
    - All columns are typed as VARCHAR/TEXT regardless of apparent source type, 
      to preserve raw fidelity. Type casting, null handling, and validation are 
      deferred to the Silver layer.
    - Table and column names match the original source dataset exactly, 
      including known inconsistencies (e.g. 'product_name_lenght' is a 
      preserved misspelling from the source data, not an error in this script).
    - Naming follows the project's <sourcesystem>_<entity> convention for the 
      Bronze layer (see naming_conventions.md).

Usage:
    1. Run this script against the 'datawarehouse' database after it has been 
       created (see 01_create_database.sql / 02_create_schemas.sql).
    2. Place the 9 Olist source CSVs in the 'datasets/' folder at the project 
       root.
    3. Load data into these tables using COPY / \copy, pointing to the files 
       in 'datasets/' (see 03_load_bronze.sql or the load scripts folder).
===============================================================================
*/

DROP TABLE IF EXISTS bronze.olist_customers;
CREATE TABLE bronze.olist_customers (
    customer_id                 VARCHAR(50),
    customer_unique_id          VARCHAR(50),
    customer_zip_code_prefix    VARCHAR(10),
    customer_city               VARCHAR(50),
    customer_state              VARCHAR(5)
);

DROP TABLE IF EXISTS bronze.olist_geolocation;
CREATE TABLE bronze.olist_geolocation (
    geolocation_zip_code_prefix    VARCHAR(10),
    geolocation_lat                VARCHAR(50),
    geolocation_lng                VARCHAR(50),
    geolocation_city               VARCHAR(50),
    geolocation_state              VARCHAR(5)
);

DROP TABLE IF EXISTS bronze.olist_order_payments;
CREATE TABLE bronze.olist_order_payments (
    order_id                 VARCHAR(50),
    payment_sequential       VARCHAR(10),
    payment_type             VARCHAR(20),
    payment_installments     VARCHAR(10),
    payment_value            VARCHAR(20)
);

DROP TABLE IF EXISTS bronze.olist_order_items;
CREATE TABLE bronze.olist_order_items (
    order_id                  VARCHAR(50),
    order_item_id             VARCHAR(10),
    product_id                VARCHAR(50),
    seller_id                 VARCHAR(50),
    shipping_limit_date       VARCHAR(50),
    price                     VARCHAR(20),
    freight_value             VARCHAR(20)
);

DROP TABLE IF EXISTS bronze.olist_order_reviews;
CREATE TABLE bronze.olist_order_reviews (
    review_id                 VARCHAR(50),
    order_id                  VARCHAR(50),
    review_score              VARCHAR(5),
    review_comment_title      VARCHAR(200),
    review_comment_message    TEXT,
    review_creation_date      VARCHAR(50),
    review_answer_timestamp   VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.olist_orders;
CREATE TABLE bronze.olist_orders (
    order_id                        VARCHAR(50),
    customer_id                     VARCHAR(50),
    order_status                    VARCHAR(20),
    order_purchase_timestamp        VARCHAR(50),
    order_approved_at               VARCHAR(50),
    order_delivered_carrier_date    VARCHAR(50),
    order_delivered_customer_date   VARCHAR(50),
    order_estimated_delivery_date   VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.olist_products;
CREATE TABLE bronze.olist_products (
    product_id                    VARCHAR(50),
    product_category_name         VARCHAR(100),
    product_name_lenght           VARCHAR(10),
    product_description_lenght    VARCHAR(10),
    product_photos_qty            VARCHAR(10),
    product_weight_g              VARCHAR(10),
    product_length_cm             VARCHAR(10),
    product_height_cm             VARCHAR(10),
    product_width_cm              VARCHAR(10)
);

DROP TABLE IF EXISTS bronze.olist_sellers;
CREATE TABLE bronze.olist_sellers (
    seller_id                VARCHAR(50),
    seller_zip_code_prefix   VARCHAR(10),
    seller_city              VARCHAR(50),
    seller_state             VARCHAR(5)
);

DROP TABLE IF EXISTS bronze.olist_product_category_name_translation;
CREATE TABLE bronze.olist_product_category_name_translation (
    product_category_name          VARCHAR(100),
    product_category_name_english  VARCHAR(100)
);
