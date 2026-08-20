# Requirements

> **Note:** This is a solo portfolio/demo project with no external stakeholder. This document articulates the project's business scope and boundaries written the way a stakeholder requirements brief would read to make the intent behind the existing design decisions explicit.
## Project Overview

Build a PostgreSQL data warehouse for Olist, a Brazilian e-commerce marketplace, following a Bronze → Silver → Gold medallion architecture. The warehouse should support analysis of sales performance, delivery logistics, and customer satisfaction using the publicly available Olist Brazilian E-Commerce dataset.

## Objectives

- Land the 9 raw Olist source files with full fidelity (Bronze).
- Profile, validate, and clean the data into a typed, trustworthy layer (Silver).
- Model a business-friendly star schema for analysis and reporting (Gold).
- Document data quality findings and design decisions at every stage, so the pipeline is auditable rather than a black box.

## Data Source

[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — 9 CSV files covering orders, order items, payments, reviews, customers, sellers, products, geolocation, and product category translations. Approximately 100,000 orders spanning September 2016 to October 2018.

## Business Questions This Warehouse Should Answer

1. **Sales performance** — What is total revenue over time (by month, quarter, year)? Which product categories generate the most revenue? Who are the highest-performing sellers?
2. **Delivery performance** — How does actual delivery time compare to estimated delivery time? Are there patterns in delayed orders by region, category, or season?
3. **Customer satisfaction** — What is the average review score, and how does it vary by order status, delivery performance, product category, or region?
4. **Payment behavior** — What payment methods are most common? How does installment count vary by payment value or product category?
5. **Order fulfillment health** — What proportion of orders are delivered vs. canceled vs. unavailable? Are there logical inconsistencies in the order lifecycle worth flagging (e.g., a "delivered" order with no delivery timestamp)?

## Explicitly Out of Scope

- **Geolocation-based analysis** (mapping, distance calculations, lat/lng-level detail). `dim_customers` and `dim_sellers` carry city/state, which is sufficient for the business questions above. `olist_geolocation` is deliberately excluded from the Gold layer — see `docs/naming_conventions.md` and `scripts/gold/ddl_gold.sql` for the reasoning.
- **Real-time or incremental loading.** All three layers use full truncate-and-reload logic; this is a demo/batch warehouse, not a production streaming pipeline.
- **Slowly Changing Dimensions (SCD).** Dimension tables reflect the current state of Silver only; historical tracking of attribute changes (e.g., a customer's city changing over time) is not implemented.
- **Free-text NLP on reviews.** `review_comment_message` and `review_comment_title` are carried through as raw text; no sentiment analysis or text mining is performed as part of this warehouse.

## Data Quality Standards

- Bronze: raw fidelity — every column stored as text, no transformation, matching source structure and naming exactly (including known source quirks, e.g. the `lenght` misspelling in `olist_products`).
- Silver: every table must pass primary/composite key uniqueness, referential integrity, NULL-pattern review, numeric/date/categorical validity, and encoding checks before being considered load-ready. Findings that can't be resolved with confidence (e.g., logically inconsistent order timestamps) are flagged via `dwh_data_quality_flag` rather than silently corrected or dropped.
- Gold: every fact view must resolve to valid dimension surrogate keys with no NULL joins; row counts must reconcile against Silver.

## Deliverables

- `docs/` — naming conventions, this requirements document, ERD, and data flow diagram.
- `scripts/` — DDL and load logic for Bronze, Silver, and Gold layers.
- `tests/` — documented SQL validation scripts for Bronze, Silver, and Gold, with findings and resolutions recorded inline.
- `README.md` — setup instructions and architecture overview.
