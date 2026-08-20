# Olist E-Commerce Data Warehouse

A PostgreSQL data warehouse built on the [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), following a Bronze → Silver → Gold medallion architecture.

## Why PostgreSQL

PostgreSQL was chosen deliberately over a licensed platform like SQL Server or a cloud-only warehouse:
- **Free and open-source** — any reviewer can clone this repo and run it locally in minutes, no licensing friction.
- **Production-relevant** — Postgres is genuinely used in real-world data warehouses, not a toy environment for this demo.

## Architecture

```
Bronze (raw, as-is)  →  Silver (cleaned, typed, validated)  →  Gold (star schema views)
```

- **Bronze**: 9 tables, one per source CSV, all columns stored as `VARCHAR`/`TEXT` regardless of apparent type. This preserves raw fidelity — nothing is transformed or corrected at this stage, only landed exactly as received.
- **Silver**: Same 9 tables, now typed (`INT`, `NUMERIC`, `TIMESTAMP`), constrained (`CHECK`, `NOT NULL`), deduplicated where needed, and cleaned based on findings from a full Bronze data quality audit.
- **Gold**: A star schema — 4 dimension views and 3 fact views — built as SQL views (not physical tables) over Silver, so the layer stays a live, always-current lens rather than a separate copy of the data.

See `docs/data_architecture.png` for a high-level view of the PostgreSQL warehouse and its consumption layer, `docs/data_flow_diagram.png` for the full table-level flow, `docs/entity_relationship_diagram.png` for the source schema relationships, and `docs/gold_layer_entity_relationship_diagram.png` for the Gold-layer star schema.

## Repository Structure

```
olist-data-warehouse/
├── datasets/                          # Olist CSVs (see Setup below)
├── docs/
│   ├── naming_conventions.md
│   ├── requirements.md
│   ├── data_architecture.png
│   ├── entity_relationship_diagram.png
│   ├── gold_layer_entity_relationship_diagram.png
│   └── data_flow_diagram.png
├── scripts/
│   ├── create_database.sql            # Creates the datawarehouse database
│   ├── create_schemas.sql             # Creates bronze/silver/gold schemas
│   ├── bronze/
│   │   ├── ddl_bronze.sql             # Table definitions (raw VARCHAR schema)
│   │   └── load_bronze.sql            # load_bronze() stored procedure
│   ├── silver/
│   │   ├── ddl_silver.sql             # Typed, constrained table definitions
│   │   └── load_silver.sql            # load_silver() stored procedure
│   └── gold/
│       └── ddl_gold.sql               # Dimension and fact views
├── tests/
│   ├── bronze_layer_data_quality_checks/
│   │   ├── check_for_distinct_values.sql
│   │   ├── check_for_null_count_for_nonkey_columns.sql
│   │   ├── check_for_numeric_and_character_validity.sql
│   │   ├── check_for_primary_key_duplicates_or_nulls.sql
│   │   ├── check_for_referential_integrity.sql
│   │   ├── check_for_unwanted_spaces.sql
│   │   └── check_for_valid_values.sql
│   ├── silver_layer_data_quality_checks/
│   │   └── all_checks_after_data_transformation.sql
│   └── gold_layer_data_quality_checks/
│       └── all_checks_for_gold_layer.sql
├── LICENSE
└── README.md
```

## Setup

1. Download the Olist dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and place the 9 CSVs in `datasets/`.
2. Create the database and schemas:
   ```sql
   \i scripts/create_database.sql
   \c datawarehouse
   \i scripts/create_schemas.sql
   ```
3. Run the Bronze DDL, then load Bronze:
   ```sql
   \i scripts/bronze/ddl_bronze.sql
   \i scripts/bronze/load_bronze.sql
   CALL bronze.load_bronze();
   ```
   > **pgAdmin note**: `COPY` runs server-side, so the PostgreSQL service account (not your OS user) needs read access to the `datasets/` folder. On Windows, check which account the `postgresql-x64-XX` service runs as (via `services.msc`) and grant that account read permissions on the folder.
4. Run the Silver DDL and load:
   ```sql
   \i scripts/silver/ddl_silver.sql
   \i scripts/silver/load_silver.sql
   CALL silver.load_silver();
   ```
5. Run the Gold DDL to create the views:
   ```sql
   \i scripts/gold/ddl_gold.sql
   ```

## Data Model (Gold Layer)

**Dimensions**
- `dim_customers` — customer identity and location
- `dim_sellers` — seller identity and location
- `dim_products` — product catalog, with Brazilian category names translated to English
- `dim_date` — generated calendar dimension (2016-01-01 to 2018-12-31)

**Facts**
- `fact_order_items` — grain: one row per order item. Core fact table, denormalized with order status/dates.
- `fact_payments` — grain: one row per payment. Kept separate from `fact_order_items` since payments and order items sit at different grains.
- `fact_reviews` — grain: one row per review.

`olist_geolocation` is deliberately excluded from Gold — `dim_customers` and `dim_sellers` already carry city/state, which covers this project's analytical scope (sales, delivery performance, reviews by region). Lat/lng-level geographic analysis was out of scope.

## Key Design Decisions

- **Bronze stores everything as raw text.** No implicit type casting on load — every column is `VARCHAR`/`TEXT`, preserving the data exactly as exported, including known source quirks (e.g., the `product_name_lenght` misspelling is intentionally kept in Bronze, corrected in Silver).
- **`olist_orders` has no dedicated Gold dimension.** It only has one categorical attribute (`order_status`) and four dates — too thin to justify a separate dimension and the extra join it would require for common queries like delivery-performance metrics. Its columns are denormalized directly into all three fact views instead.
- **`dwh_data_quality_flag`** on `fact_order_items` flags rows with logical inconsistencies found during validation (e.g., an order marked `delivered` with no delivery date recorded, or `canceled` orders with a populated delivery date) rather than silently dropping or "fixing" them — this preserves auditability while still letting downstream queries filter them out if needed.
- **`'Uncategorized'` / `'Unknown'` placeholders** replace NULLs in `dim_products.product_category_name_english` and `dim_sellers.seller_city` respectively, for BI-tool friendliness (NULLs behave inconsistently in filters and groupings) — applied only to text/categorical fields.

## Data Quality

Every Bronze table went through a structured quality audit before any Silver transformation was written: primary/composite key integrity, unwanted whitespace, referential integrity across all 9 tables, NULL patterns on non-key columns, and numeric/date/categorical validity — including a systematic sweep for the UTF-8/Latin-1 encoding corruption present in several free-text and place-name columns. Findings and resolutions are documented inline in each file under `tests/`.

Notable findings, investigated and resolved rather than silently patched:
- `olist_order_reviews.review_id` is not unique on its own (789 rows) — the true composite key is `(review_id, order_id)`.
- `olist_geolocation` has 128,000+ full-row exact duplicates (expected — multiple delivery points share coordinates) — deduplicated to one row per zip prefix in Silver.
- Two product categories (`eletrodomesticos_2`, `casa_conforto_2`) appear to be duplicate/re-entered versions of existing categories, based on a spelling correction visible in their English translations.
- `seller_city` contained a mix of genuine data (18 rows with city/state/country jammed into one field, cleaned via string extraction) and true junk (an email address, a phone number — replaced with `'Unknown'`).
- A known gap exists in November 2016 (zero orders) — confirmed as genuine in the source data, consistent with Olist's documented low order volume in its early platform months.

## Naming Conventions

Full conventions are documented in `docs/naming_conventions.md`. In summary:
- `snake_case` throughout.
- Bronze/Silver tables: `<sourcesystem>_<entity>` (e.g., `olist_customers`).
- Gold tables: `<category>_<entity>` (e.g., `dim_customers`, `fact_order_items`).
- Surrogate keys: `<table_name>_key`.
- Technical/metadata columns: `dwh_<column_name>` prefix.
- Stored procedures: `load_<layer>`.

## Author

Suyog Wagle — [github.com/suyogwagle](https://github.com/suyogwagle)
