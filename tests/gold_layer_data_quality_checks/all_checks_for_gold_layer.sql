/*
===============================================================================
Quality Checks: Gold Layer — Star Schema Validation
===============================================================================
Purpose:
  Verifies that the Gold-layer views (dimensions and facts) resolve correctly
	no broken surrogate key joins, row counts align with Silver, dim_date coverage is sufficient for the fact tables' date ranges, 
  and a sample business question resolves correctly end to end through the star schema. 
	Since Gold consists of views (not loaded/stored tables), these checks validate the join logic itself rather than post-load state.
===============================================================================
*/

-- Row Count Sanity Checks

-- Check row counts across all Gold views
-- Expectation: dimension counts should match their Silver source table counts
SELECT 'dim_customers' AS view_name, COUNT(*) FROM gold.dim_customers
UNION ALL SELECT 'dim_sellers', COUNT(*) FROM gold.dim_sellers
UNION ALL SELECT 'dim_products', COUNT(*) FROM gold.dim_products
UNION ALL SELECT 'dim_date', COUNT(*) FROM gold.dim_date
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM gold.fact_order_items
UNION ALL SELECT 'fact_payments', COUNT(*) FROM gold.fact_payments
UNION ALL SELECT 'fact_reviews', COUNT(*) FROM gold.fact_reviews;
-- Result: dimension counts match their Silver source table counts


-- Surrogate Key Integrity Checks (broken join detection)

-- Check for NULL surrogate keys in fact_order_items
-- Expectation: 0 rows returned since every order item should resolve to a valid customer, product, and seller
SELECT order_id, order_item_id, customer_key, product_key, seller_key
FROM gold.fact_order_items
WHERE customer_key IS NULL OR product_key IS NULL OR seller_key IS NULL;
-- Result: 0 rows returned; every order item resolves to a valid customer, product, and seller


-- Check for NULL order_date_key in fact_order_items
-- Expectation: 0 rows returned since every order should have a valid purchase timestamp to derive a date_key from
SELECT order_id, order_item_id, order_date_key
FROM gold.fact_order_items
WHERE order_date_key IS NULL;
-- Result: 0 rows returned since every order has a valid purchase timestamp


-- Check for NULL surrogate keys in fact_payments
-- Expectation: 0 rows returned
SELECT order_id, payment_sequential, customer_key, order_date_key
FROM gold.fact_payments
WHERE customer_key IS NULL OR order_date_key IS NULL;
-- Result: 0 rows returned


-- Check for NULL surrogate keys in fact_reviews
-- Expectation: 0 rows returned
SELECT review_id, order_id, customer_key, order_date_key
FROM gold.fact_reviews
WHERE customer_key IS NULL OR order_date_key IS NULL;
-- Result: 0 rows returned


-- Dimension Key Uniqueness Checks

-- Confirm surrogate keys are unique in dim_customers
-- Expectation: 0 rows returned
SELECT customer_key, COUNT(*)
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;
-- Result: 0 rows returned


-- Confirm surrogate keys are unique in dim_sellers
-- Expectation: 0 rows returned
SELECT seller_key, COUNT(*)
FROM gold.dim_sellers
GROUP BY seller_key
HAVING COUNT(*) > 1;
-- Result: 0 rows returned


-- Confirm surrogate keys are unique in dim_products
-- Expectation: 0 rows returned
SELECT product_key, COUNT(*)
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;
-- Result: 0 rows returned


-- Confirm surrogate keys are unique in dim_date
-- Expectation: 0 rows returned
SELECT date_key, COUNT(*)
FROM gold.dim_date
GROUP BY date_key
HAVING COUNT(*) > 1;
-- Result: 0 rows returned


-- dim_date Coverage Check

-- Confirm dim_date's generated range (2016-01-01 to 2018-12-31) fully covers the actual date range present in the fact tables
-- Expectation: min/max fact dates fall within dim_date's range
SELECT 
    MIN(order_purchase_timestamp) AS earliest_order,
    MAX(order_purchase_timestamp) AS latest_order
FROM silver.olist_orders;
-- Result: the earliest order was made in 2016-09-04 and the latest order was made in 2018-10-17 which are both covered by the dim_date's range


-- Check for any order_date_key in fact_order_items that has no match in dim_date
-- Expectation: 0 rows returned
SELECT f.order_id, f.order_date_key
FROM gold.fact_order_items f
LEFT JOIN gold.dim_date d ON f.order_date_key = d.date_key
WHERE d.date_key IS NULL;
-- Result: 0 rows returned


-- Cross-Check Against Silver (confirm Gold views aren't silently dropping rows)

-- Confirm fact_order_items row count matches silver.olist_order_items exactly
-- Expectation: both counts equal
SELECT 
    (SELECT COUNT(*) FROM silver.olist_order_items) AS silver_count,
    (SELECT COUNT(*) FROM gold.fact_order_items) AS gold_count;
-- Result: both counts equal


-- Confirm fact_payments row count matches silver.olist_order_payments exactly
-- Expectation: both counts equal
SELECT 
    (SELECT COUNT(*) FROM silver.olist_order_payments) AS silver_count,
    (SELECT COUNT(*) FROM gold.fact_payments) AS gold_count;
-- Result: both counts equal


-- Confirm fact_reviews row count matches silver.olist_order_reviews exactly
-- Expectation: both counts equal
SELECT 
    (SELECT COUNT(*) FROM silver.olist_order_reviews) AS silver_count,
    (SELECT COUNT(*) FROM gold.fact_reviews) AS gold_count;
-- Result: both counts equal


-- Business Logic Sanity Checks (proving the star schema resolves end to end)

-- Total revenue by year/month — confirms fact_order_items joins cleanly to dim_date and produces a sensible time series
-- Expectation: non-null, non-zero revenue figures across the known Olist dataset window
SELECT d.year, d.month, d.month_name, SUM(f.price) AS total_revenue, COUNT(*) AS total_items
FROM gold.fact_order_items f
JOIN gold.dim_date d ON f.order_date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;
-- Result: starts from 2016 September and ends at 2018 September. Missed month is 2016 November only


-- Confirm there are truly zero orders in November 2016 (not a join issue)
-- Expectation: 0 counts returned
SELECT COUNT(*) 
FROM silver.olist_orders 
WHERE order_purchase_timestamp >= '2016-11-01' AND order_purchase_timestamp < '2016-12-01';
-- Result: 0 counts returned


-- Top 5 product categories by revenue — confirms fact_order_items joins cleanly to dim_products, including the 'Uncategorized' placeholder rows
-- Expectation: All the unique product category rows returned
SELECT p.product_category_name_english, SUM(f.price) AS total_revenue
FROM gold.fact_order_items f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_category_name_english
ORDER BY total_revenue DESC;
-- Result: 74 rows returned, also includes 'Uncategorized'


-- Average review score by order_status — confirms fact_reviews resolves correctly and the denormalized order_status column is usable directly
-- Expectation: 'delivered' orders should have a meaningfully higher average score than 'canceled'/'unavailable' orders
SELECT order_status, ROUND(AVG(review_score), 2) AS avg_review_score, COUNT(*) AS total_reviews
FROM gold.fact_reviews
GROUP BY order_status
ORDER BY avg_review_score DESC;
-- Result: 'delivered' orders have an average of 4.16 with average of 'approved' being 2.50 the immediately lower average


-- Sellers with the most 'Unknown' city values still resolve correctly in dim_sellers — confirms the Silver-layer 'Unknown' placeholder carried through Gold without breaking the view
-- Expectation: 2 rows returned (the 2 sellers with junk original city values)
SELECT seller_id, seller_city, seller_state
FROM gold.dim_sellers
WHERE seller_city = 'Unknown';
-- Result: 2 rows returned
