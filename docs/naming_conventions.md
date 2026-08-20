# Naming Conventions

This document defines the naming standards used across the retail data warehouse — tables, columns, and stored procedures — for consistency and readability across the Bronze, Silver, and Gold layers.

## General Principles

- **Naming Conventions**: Use `snake_case`, with lowercase letters and underscores (`_`) to separate words.
- **Language**: Use English for all names.
- **Avoid Reserved Words**: Do not use SQL reserved words as object names.

## Table Naming Conventions

### Bronze Rules

All names must start with the source system name, and table names must match their original names without renaming.

`<sourcesystem>_<entity>`

- `<sourcesystem>`: Name of the source system (e.g., `olist`).
- `<entity>`: Exact table name from the source system.
- Example: `olist_order_items` → Order line items exported from the Olist source data.

### Silver Rules

All names must start with the source system name, and table names must match their original names without renaming.

`<sourcesystem>_<entity>`

- Same pattern as Bronze — the Silver layer holds cleaned versions of the same source entities, so names stay traceable back to their origin.
- Example: `olist_order_items` → Cleaned, standardized order line items.

### Gold Rules

All names must be business-friendly and describe the entity's role in the model, not its source system.

`<category>_<entity>`

- `<category>`: The role of the table in the model — `dim` for dimension tables, `fact` for fact tables.
- `<entity>`: Descriptive, business-aligned name.
- Examples: `dim_customers`, `dim_products`, `dim_date`, `fact_order_items`.

## Column Naming Conventions

### Surrogate Keys

All primary keys in dimension tables must use the suffix `_key`.

`<table_name>_key`

- `<table_name>`: Refers to the name of the table or entity the key belongs to.
- `_key`: A suffix indicating that this column is a surrogate key.
- Example: `customer_key` → Surrogate key in the `dim_customers` table.

### Technical Columns

All technical columns must start with the prefix `dwh_`, followed by a descriptive name indicating the column's purpose.

`dwh_<column_name>`

- `dwh`: Prefix exclusively for system-generated metadata.
- `<column_name>`: Descriptive name indicating the column's purpose.
- Example: `dwh_load_date` → System-generated column used to store the date when the record was loaded.

## Stored Procedure Naming

All stored procedures used for loading data must follow the naming pattern:

`load_<layer>`

- `<layer>`: Represents the layer being loaded — `bronze`, `silver`, or `gold`.
- Examples:
  - `load_bronze` → Stored procedure for loading data into the Bronze layer.
  - `load_silver` → Stored procedure for loading data into the Silver layer.
  - `load_gold` → Stored procedure for loading data into the Gold layer.
