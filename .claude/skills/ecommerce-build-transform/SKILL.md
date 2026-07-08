---
name: ecommerce-build-transform
description: >-
  Build the Medallion transformation layer with dbt for the Retail Analytics POC (spec
  phases 3-4). Use when creating the dbt-postgres project, defining Bronze sources, writing
  Silver staging/cleaning models (dedupe, null handling, type/column standardization), and
  building Gold business models (dim_customer, dim_product, dim_date, fact_sales star
  schema), plus dbt tests and documentation. Triggers: "medallion", "silver layer",
  "gold layer", "dbt models", "star schema", "dim_customer", "fact_sales", "dbt tests",
  "dbt docs".
---

# Build & Transform — Medallion via dbt (Phases 3-4)

Read `design/ARCHITECTURE.md` §5 (layer contracts + star schema) first.
Stack: **dbt-postgres** transforming inside `warehouse-postgres` — reads `bronze.*`,
builds `silver.*`, then `gold.*`. (Variant: dbt-duckdb over MinIO Parquet — ARCHITECTURE §2.)

## Deliverables checklist
- [ ] dbt project `dbt/retail/` initialized on the `postgres` adapter (targets warehouse)
- [ ] Bronze declared as dbt **sources** (`bronze` schema tables)
- [ ] Silver `stg_*` models in `silver`: dedupe, null handling, typing, standardization
- [ ] Gold in `gold`: `dim_customer`, `dim_product`, `dim_date`, `fact_sales` (star schema)
- [ ] dbt **tests** (generic + expectations) passing
- [ ] dbt **docs** generated (`dbt docs generate`)

## Phase 3-4 steps

1. **Init project.** `dbt/retail/` with an env-based profile targeting `warehouse-postgres`
   (host/port from `deploy/.env`; default schema per layer via `+schema` configs). Add
   `dbt-utils` + `dbt-expectations` to `packages.yml`. dbt runs inside the Airflow image
   (Cosmos) and can also run ad hoc via `docker compose run`. Layout:
   ```
   models/
     staging/   # → silver:  stg_customers, stg_products, stg_orders,
                #            stg_order_items, stg_payments        (tag: silver, schema: silver)
     marts/     # → gold:    dim_customer, dim_product, dim_date, fact_sales
                #                                                 (tag: gold, schema: gold)
   ```
2. **Bronze as sources** (`models/staging/_sources.yml`): declare each `bronze.<table>`
   Airbyte lands. Add freshness where sensible. **Never** materialize into Bronze — read-only.
3. **Silver (`stg_*`)** — one model per source table, materialized as `view` (or table):
   - **Dedupe:** `row_number()` over PK ordered by `updated_at desc`, keep rn=1
     (drops Airbyte append duplicates).
   - **Nulls:** coalesce defaults, drop rows missing a required key, flag bad rows.
   - **Types:** cast to proper types (dates, numerics, booleans).
   - **Standardize:** snake_case columns, trim strings, upper-case codes
     (country, status, payment_status), normalize emails to lower-case.
4. **Gold (marts)** — materialized as `table`:
   - `dim_customer`, `dim_product` — surrogate key (`dbt_utils.generate_surrogate_key`), SCD-1.
   - `dim_date` — generated calendar spanning order dates.
   - `fact_sales` — grain = order line item; join order_items → orders → payments →
     dims; compute `line_amount = quantity * unit_price`; carry FKs to all dims.
5. **Tests** (`_models.yml` per folder):
   - Keys: `unique` + `not_null` on every PK/SK.
   - `relationships`: fact FKs → each dim SK.
   - `accepted_values`: order status, payment_status, payment_method.
   - `dbt_expectations`: row-count between min/max, non-negative amounts, no future dates.
6. **Docs:** add `description:` to every model/column; `dbt docs generate` (feeds the
   Phase-9 data dictionary).

## Build & verify
- `dbt build` (runs models + tests) is green end to end.
- `select count(*) from gold.fact_sales` matches expected order-line volume.
- Spot-check: total `line_amount` in `gold` ≈ sum of source order_items — this preview of
  reconciliation is formalized in `ecommerce-orchestrate-operate`.

## Common gotchas
- Cleaning in Bronze — cleaning belongs in Silver only.
- Duplicate fact rows from fan-out joins — verify grain stays at order-line.
- Surrogate keys built from nullable columns — build them from stable natural keys.
- Hardcoded connection — parameterize via env vars so CI can point at an ephemeral Postgres.

Prev: `ecommerce-setup-ingest`. Next: `ecommerce-orchestrate-operate`.
