/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from the Olist e-commerce source CSV files. It performs the following actions:
    - Truncates each bronze table before loading, so the procedure is safe to re-run without creating duplicate data.
    - Uses the COPY command to bulk load data from CSV files into bronze tables.
    - Logs progress and load duration per table, plus total batch duration, via RAISE NOTICE (visible in pgAdmin's Messages tab or psql output).
    - Catches and reports any errors encountered during the load.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Prerequisites:
    - The 'bronze' schema and its 9 tables must already exist (see ddl_bronze.sql).
    - CSV file paths below are absolute Windows paths and will need to be updated to match your local environment.
    - IMPORTANT: COPY runs server-side, meaning the PostgreSQL service account (not your OS user account) must have read permissions on the folder containing the 
      CSV files. On Windows, this typically means granting read access to the account the PostgreSQL service runs as (e.g. Network Service or a dedicated postgres 
      service account).

Usage Example:
    CALL bronze.load_bronze();
===============================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
DECLARE
    start_time         TIMESTAMP;
    end_time            TIMESTAMP;
    batch_start_time    TIMESTAMP;
    batch_end_time      TIMESTAMP;
BEGIN
    BEGIN
        batch_start_time := clock_timestamp();
        RAISE NOTICE '================================================';
        RAISE NOTICE 'Loading Bronze Layer';
        RAISE NOTICE '================================================';

        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: bronze.olist_customers';
        TRUNCATE TABLE bronze.olist_customers;
        RAISE NOTICE '>> Inserting Data Into: bronze.olist_customers';
        COPY bronze.olist_customers
        FROM 'C:\Users\Acer\Desktop\data engineering\data_warehouse_project\Brazilian_Ecommerce_Public_Dataset\olist_customers_dataset.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';

        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: bronze.olist_geolocation';
        TRUNCATE TABLE bronze.olist_geolocation;
        RAISE NOTICE '>> Inserting Data Into: bronze.olist_geolocation';
        COPY bronze.olist_geolocation
        FROM 'C:\Users\Acer\Desktop\data engineering\data_warehouse_project\Brazilian_Ecommerce_Public_Dataset\olist_geolocation_dataset.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';

        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: bronze.olist_order_items';
        TRUNCATE TABLE bronze.olist_order_items;
        RAISE NOTICE '>> Inserting Data Into: bronze.olist_order_items';
        COPY bronze.olist_order_items
        FROM 'C:\Users\Acer\Desktop\data engineering\data_warehouse_project\Brazilian_Ecommerce_Public_Dataset\olist_order_items_dataset.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';

        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: bronze.olist_order_payments';
        TRUNCATE TABLE bronze.olist_order_payments;
        RAISE NOTICE '>> Inserting Data Into: bronze.olist_order_payments';
        COPY bronze.olist_order_payments
        FROM 'C:\Users\Acer\Desktop\data engineering\data_warehouse_project\Brazilian_Ecommerce_Public_Dataset\olist_order_payments_dataset.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';

        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: bronze.olist_order_reviews';
        TRUNCATE TABLE bronze.olist_order_reviews;
        RAISE NOTICE '>> Inserting Data Into: bronze.olist_order_reviews';
        COPY bronze.olist_order_reviews
        FROM 'C:\Users\Acer\Desktop\data engineering\data_warehouse_project\Brazilian_Ecommerce_Public_Dataset\olist_order_reviews_dataset.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';

        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: bronze.olist_orders';
        TRUNCATE TABLE bronze.olist_orders;
        RAISE NOTICE '>> Inserting Data Into: bronze.olist_orders';
        COPY bronze.olist_orders
        FROM 'C:\Users\Acer\Desktop\data engineering\data_warehouse_project\Brazilian_Ecommerce_Public_Dataset\olist_orders_dataset.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';

        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: bronze.olist_products';
        TRUNCATE TABLE bronze.olist_products;
        RAISE NOTICE '>> Inserting Data Into: bronze.olist_products';
        COPY bronze.olist_products
        FROM 'C:\Users\Acer\Desktop\data engineering\data_warehouse_project\Brazilian_Ecommerce_Public_Dataset\olist_products_dataset.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';

        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: bronze.olist_sellers';
        TRUNCATE TABLE bronze.olist_sellers;
        RAISE NOTICE '>> Inserting Data Into: bronze.olist_sellers';
        COPY bronze.olist_sellers
        FROM 'C:\Users\Acer\Desktop\data engineering\data_warehouse_project\Brazilian_Ecommerce_Public_Dataset\olist_sellers_dataset.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';

        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: bronze.olist_product_category_name_translation';
        TRUNCATE TABLE bronze.olist_product_category_name_translation;
        RAISE NOTICE '>> Inserting Data Into: bronze.olist_product_category_name_translation';
        COPY bronze.olist_product_category_name_translation
        FROM 'C:\Users\Acer\Desktop\data engineering\data_warehouse_project\Brazilian_Ecommerce_Public_Dataset\product_category_name_translation.csv'
        WITH (FORMAT csv, HEADER true, DELIMITER ',');
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';

        batch_end_time := clock_timestamp();
        RAISE NOTICE '==========================================';
        RAISE NOTICE 'Loading Bronze Layer is Completed';
        RAISE NOTICE '   - Total Load Duration: % seconds', EXTRACT(SECOND FROM batch_end_time - batch_start_time);
        RAISE NOTICE '==========================================';

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '==========================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        RAISE NOTICE 'Error Message: %', SQLERRM;
        RAISE NOTICE 'Error State: %', SQLSTATE;
        RAISE NOTICE '==========================================';
    END;
END;
$$;

-- Usage Example:
    CALL bronze.load_bronze();
