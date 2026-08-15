/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'silver' schema from the 'bronze' schema. It performs the following actions:
    - Truncates each silver table before loading, so the procedure is safe to re-run without creating duplicate data.
    - Applies type casting, deduplication, and targeted cleaning based on findings from the Bronze-layer data quality checks.
    - Logs progress and load duration per table, plus total batch duration, via RAISE NOTICE (visible in pgAdmin's Messages tab or psql output).
    - Catches and reports any errors encountered during the load.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Load Order Note:
    olist_product_category_name_translation must load before olist_products, since the products load joins to the translation table to resolve product_category_name_english.

Usage Example:
    CALL silver.load_silver();
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
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
        RAISE NOTICE 'Loading Silver Layer';
        RAISE NOTICE '================================================';
		
		
		-- olist_customers
        -- No row-level cleaning required as Bronze confirmed no duplicate/NULL keys, no encoding issues, fully valid state codes. Straight type cast.
        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: silver.olist_customers';
        TRUNCATE TABLE silver.olist_customers;
        RAISE NOTICE '>> Inserting Data Into: silver.olist_customers';
        INSERT INTO silver.olist_customers (
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,
            customer_city,
            customer_state
        )
        SELECT
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,
            customer_city,
            customer_state
        FROM bronze.olist_customers;
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';


        -- olist_geolocation
        -- Casts lat/lng to NUMERIC, fixes 7 confirmed encoding-corrupted city values, and deduplicates to one row per zip prefix (Bronze confirmed 128,178+ full-row exact duplicates).
        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: silver.olist_geolocation';
        TRUNCATE TABLE silver.olist_geolocation;
        RAISE NOTICE '>> Inserting Data Into: silver.olist_geolocation';
        INSERT INTO silver.olist_geolocation (
            geolocation_zip_code_prefix,
            geolocation_lat,
            geolocation_lng,
            geolocation_city,
            geolocation_state
        )
        SELECT
            geolocation_zip_code_prefix,
            geolocation_lat,
            geolocation_lng,
            geolocation_city,
            geolocation_state
        FROM (
            SELECT
                geolocation_zip_code_prefix,
                CAST(geolocation_lat AS NUMERIC(10,7)) AS geolocation_lat,
                CAST(geolocation_lng AS NUMERIC(10,7)) AS geolocation_lng,
                CASE
                    WHEN geolocation_city = 'lambari d%26apos%3boeste' THEN 'lambari d''oeste'
                    WHEN geolocation_city = 'são joão do pau d%26apos%3balho' THEN 'são joão do pau d''alho'
                    WHEN geolocation_city = 'florian&oacute;polis' THEN 'florianópolis'
                    WHEN geolocation_city = 'maceia³' THEN 'maceió'
                    WHEN geolocation_city = 'sa£o paulo' THEN 'são paulo'
                    WHEN geolocation_city = '´teresopolis' THEN 'teresópolis'
                    WHEN geolocation_city = 'santa bárbara d`oeste' THEN 'santa bárbara d''oeste'
                    ELSE geolocation_city
                END AS geolocation_city,
                geolocation_state,
                ROW_NUMBER() OVER (
                    PARTITION BY geolocation_zip_code_prefix
                    ORDER BY geolocation_zip_code_prefix
                ) AS row_num
            FROM bronze.olist_geolocation
        ) sub
        WHERE row_num = 1;
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';


        -- olist_order_items
        -- (order_id, order_item_id) confirmed unique composite key in Bronze, no NULLs, no negative price/freight_value, valid date format throughout.
        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: silver.olist_order_items';
        TRUNCATE TABLE silver.olist_order_items;
        RAISE NOTICE '>> Inserting Data Into: silver.olist_order_items';
        INSERT INTO silver.olist_order_items (
            order_id,
            order_item_id,
            product_id,
            seller_id,
            shipping_limit_date,
            price,
            freight_value
        )
        SELECT
            order_id,
            CAST(order_item_id AS INT),
            product_id,
            seller_id,
            TO_TIMESTAMP(shipping_limit_date, 'DD/MM/YYYY HH24:MI'),
            CAST(price AS NUMERIC(10,2)),
            CAST(freight_value AS NUMERIC(10,2))
        FROM bronze.olist_order_items;
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';


        -- olist_order_payments
        -- (order_id, payment_sequential) confirmed unique composite key in Bronze. 
		-- payment_type/payment_installments validity enforced by table CHECK constraints so it is not re-validated here.
        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: silver.olist_order_payments';
        TRUNCATE TABLE silver.olist_order_payments;
        RAISE NOTICE '>> Inserting Data Into: silver.olist_order_payments';
        INSERT INTO silver.olist_order_payments (
            order_id,
            payment_sequential,
            payment_type,
            payment_installments,
            payment_value
        )
        SELECT
            order_id,
            CAST(payment_sequential AS INT),
            payment_type,
            CASE 
			    WHEN CAST(payment_installments AS INT) < 1 THEN 1 
			    ELSE CAST(payment_installments AS INT) 
			END,
            CAST(payment_value AS NUMERIC(10,2))
        FROM bronze.olist_order_payments;
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';


        -- olist_order_reviews
        -- Trims leading/trailing spaces from review_comment_title/message (Bronze confirmed 9,317 affected rows) and casts dates using explicit DD/MM/YYYY format. 
		-- review_score range enforced by table 
        -- CHECK constraint. All "blank" comment values confirmed true NULL, not empty strings hence no additional normalization needed.
        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: silver.olist_order_reviews';
        TRUNCATE TABLE silver.olist_order_reviews;
        RAISE NOTICE '>> Inserting Data Into: silver.olist_order_reviews';
        INSERT INTO silver.olist_order_reviews (
            review_id,
            order_id,
            review_score,
            review_comment_title,
            review_comment_message,
            review_creation_date,
            review_answer_timestamp
        )
        SELECT
            review_id,
            order_id,
            CAST(review_score AS INT),
            NULLIF(TRIM(review_comment_title), '') AS review_comment_title,
			NULLIF(TRIM(review_comment_message), '') AS review_comment_message,
            TO_TIMESTAMP(review_creation_date, 'DD/MM/YYYY HH24:MI'),
            TO_TIMESTAMP(review_answer_timestamp, 'DD/MM/YYYY HH24:MI')
        FROM bronze.olist_order_reviews;
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';
		
		
		-- olist_orders
        -- Loads all rows. Flags 14 rows with logical status/date inconsistencies found in Bronze via dwh_data_quality_flag.
        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: silver.olist_orders';
        TRUNCATE TABLE silver.olist_orders;
        RAISE NOTICE '>> Inserting Data Into: silver.olist_orders';
        INSERT INTO silver.olist_orders (
            order_id,
            customer_id,
            order_status,
            order_purchase_timestamp,
            order_approved_at,
            order_delivered_carrier_date,
            order_delivered_customer_date,
            order_estimated_delivery_date,
            dwh_data_quality_flag
        )
        SELECT
            order_id,
            customer_id,
            order_status,
            TO_TIMESTAMP(order_purchase_timestamp, 'DD/MM/YYYY HH24:MI'),
            TO_TIMESTAMP(order_approved_at, 'DD/MM/YYYY HH24:MI'),
            TO_TIMESTAMP(order_delivered_carrier_date, 'DD/MM/YYYY HH24:MI'),
            TO_TIMESTAMP(order_delivered_customer_date, 'DD/MM/YYYY HH24:MI'),
            TO_TIMESTAMP(order_estimated_delivery_date, 'DD/MM/YYYY HH24:MI'),
			CASE
			    WHEN order_status = 'delivered' AND order_delivered_customer_date IS NULL 
			        THEN 'inconsistent_delivered_no_date'
			    WHEN order_status = 'canceled' AND order_delivered_customer_date IS NOT NULL 
			        THEN 'inconsistent_canceled_has_date'
			    WHEN order_delivered_carrier_date IS NOT NULL AND order_approved_at IS NOT NULL 
			         AND TO_TIMESTAMP(order_delivered_carrier_date, 'DD/MM/YYYY HH24:MI') < TO_TIMESTAMP(order_approved_at, 'DD/MM/YYYY HH24:MI')
			         AND TO_TIMESTAMP(order_approved_at, 'DD/MM/YYYY HH24:MI') - TO_TIMESTAMP(order_delivered_carrier_date, 'DD/MM/YYYY HH24:MI') > INTERVAL '1 day'
			        THEN 'inconsistent_carrier_before_approval_severe'
			    WHEN order_delivered_carrier_date IS NOT NULL AND order_approved_at IS NOT NULL 
			         AND TO_TIMESTAMP(order_delivered_carrier_date, 'DD/MM/YYYY HH24:MI') < TO_TIMESTAMP(order_approved_at, 'DD/MM/YYYY HH24:MI')
			        THEN 'inconsistent_carrier_before_approval_minor'
			    WHEN order_delivered_customer_date IS NOT NULL AND order_delivered_carrier_date IS NOT NULL 
			         AND TO_TIMESTAMP(order_delivered_customer_date, 'DD/MM/YYYY HH24:MI') < TO_TIMESTAMP(order_delivered_carrier_date, 'DD/MM/YYYY HH24:MI')
			         AND TO_TIMESTAMP(order_delivered_carrier_date, 'DD/MM/YYYY HH24:MI') - TO_TIMESTAMP(order_delivered_customer_date, 'DD/MM/YYYY HH24:MI') > INTERVAL '1 day'
			        THEN 'inconsistent_customer_before_carrier_severe'
			    WHEN order_delivered_customer_date IS NOT NULL AND order_delivered_carrier_date IS NOT NULL 
			         AND TO_TIMESTAMP(order_delivered_customer_date, 'DD/MM/YYYY HH24:MI') < TO_TIMESTAMP(order_delivered_carrier_date, 'DD/MM/YYYY HH24:MI')
			        THEN 'inconsistent_customer_before_carrier_minor'
			    ELSE 'valid'
            END AS dwh_data_quality_flag
        FROM bronze.olist_orders;
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';


        -- olist_product_category_name_translation
        -- No row-level cleaning required as Bronze confirmed no duplicate/NULL keys and straight type cast.
        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: silver.olist_product_category_name_translation';
        TRUNCATE TABLE silver.olist_product_category_name_translation;
        RAISE NOTICE '>> Inserting Data Into: silver.olist_product_category_name_translation';
        INSERT INTO silver.olist_product_category_name_translation (
            product_category_name,
            product_category_name_english
        )
        SELECT
            product_category_name,
            product_category_name_english
        FROM bronze.olist_product_category_name_translation;
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';


        -- olist_products
        -- Casts numeric columns; product_name_length/product_description_length read from Bronze's misspelled source columns (product_name_lenght/product_description_lenght)
		-- Resolves product_category_name_english via LEFT JOIN to silver.olist_product_category_name_translation, with COALESCE falling back to the original Portuguese category name 
		-- for the 2 categories confirmed missing from the translation table ('portateis_cozinha_e_preparadores_de_alimentos', 'pc_gamer'), 
		-- and to NULL for the 610 products confirmed to have no category at all. 
        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: silver.olist_products';
        TRUNCATE TABLE silver.olist_products;
        RAISE NOTICE '>> Inserting Data Into: silver.olist_products';
        INSERT INTO silver.olist_products (
            product_id,
            product_category_name,
            product_category_name_english,
            product_name_length,
            product_description_length,
            product_photos_qty,
            product_weight_g,
            product_length_cm,
            product_height_cm,
            product_width_cm
        )
        SELECT
            p.product_id,
            p.product_category_name,
            COALESCE(t.product_category_name_english, p.product_category_name) AS product_category_name_english,
            CAST(p.product_name_lenght AS INT),
            CAST(p.product_description_lenght AS INT),
            CAST(p.product_photos_qty AS INT),
            CAST(p.product_weight_g AS NUMERIC(10,2)),
            CAST(p.product_length_cm AS NUMERIC(10,2)),
            CAST(p.product_height_cm AS NUMERIC(10,2)),
            CAST(p.product_width_cm AS NUMERIC(10,2))
        FROM bronze.olist_products p
        LEFT JOIN silver.olist_product_category_name_translation t
            ON p.product_category_name = t.product_category_name;
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';


        -- olist_sellers
        -- seller_city cleaned per Bronze findings: extracts just the city portion from the 18 rows with structural city/state/country combos (split on '/', ',', or '\', keep first segment), 
		-- and nullifies the 2 genuine junk values (an email address, a phone number) rather than treating them as real city names.
        start_time := clock_timestamp();
        RAISE NOTICE '>> Truncating Table: silver.olist_sellers';
        TRUNCATE TABLE silver.olist_sellers;
        RAISE NOTICE '>> Inserting Data Into: silver.olist_sellers';
        INSERT INTO silver.olist_sellers (
            seller_id,
            seller_zip_code_prefix,
            seller_city,
            seller_state
        )
        SELECT
            seller_id,
            seller_zip_code_prefix,
            CASE
				WHEN seller_city IN ('vendas@creditparts.com.br', '4482255') THEN 'Unknown'
				ELSE TRIM(SPLIT_PART(SPLIT_PART(SPLIT_PART(seller_city, '/', 1), ',', 1), '\', 1))
            END AS seller_city,
            seller_state
        FROM bronze.olist_sellers;
        end_time := clock_timestamp();
        RAISE NOTICE '>> Load Duration: % seconds', EXTRACT(SECOND FROM end_time - start_time);
        RAISE NOTICE '>> -------------';


        batch_end_time := clock_timestamp();
        RAISE NOTICE '==========================================';
        RAISE NOTICE 'Loading Silver Layer is Completed';
        RAISE NOTICE '   - Total Load Duration: % seconds', EXTRACT(SECOND FROM batch_end_time - batch_start_time);
        RAISE NOTICE '==========================================';

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '==========================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        RAISE NOTICE 'Error Message: %', SQLERRM;
        RAISE NOTICE 'Error State: %', SQLSTATE;
        RAISE NOTICE '==========================================';
    END;
END;
$$;
