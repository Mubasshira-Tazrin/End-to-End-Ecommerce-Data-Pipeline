---
name: ecommerce-setup-ingest
description: >-
  Build the source system and ingestion layer for the Retail Analytics POC (spec
  phases 1-2). Use when setting up the PostgreSQL source database, creating retail
  tables, loading sample CSV data, loading products from a public API in Python, or
  configuring Airbyte OSS full-refresh and incremental syncs that land raw data into the
  Bronze schema of the warehouse Postgres. All services run in Docker. Triggers:
  "source setup", "postgres source", "load csv", "public API loader", "airbyte",
  "ingestion", "bronze", "full refresh", "incremental sync", "docker".
---

# Setup & Ingest — Source system + Airbyte (Phases 1-2)

Read `design/ARCHITECTURE.md` §4-§5 and `design/DEPLOYMENT.md` §2,§5 before starting.
Stack (Docker): `source-postgres` container, Python loaders, Airbyte OSS (`abctl`) →
`bronze` schema in `warehouse-postgres`.

## Deliverables checklist
- [ ] `source-postgres` container up, schema `retail` + 5 tables, auto-seeded from DDL (§4)
- [ ] `warehouse-postgres` container up (empty `bronze`/`silver`/`gold` schemas)
- [ ] Dummy/CSV seed data present (customers, orders, order_items, payments)
- [ ] Products loaded from a **public API** via a Python script
- [ ] Airbyte OSS running; Postgres source + Postgres (`bronze`) destination configured
- [ ] **Full refresh** sync working
- [ ] **Incremental** sync working (cursor = `updated_at`, dedup on PK)
- [ ] Raw data landed in `warehouse.bronze.*`

## Phase 1 — Source setup (Docker)

1. **Containers.** Define `source-postgres` and `warehouse-postgres` in
   `deploy/docker-compose.yml` (postgres:16, named volumes, host ports 5433/5434 to avoid
   clashing with any native Postgres). See DEPLOYMENT §2-§3.
2. **Auto-seed.** Mount `source/ddl/ → /docker-entrypoint-initdb.d/:ro` so the source DB
   creates schema `retail` + the 5 tables and loads dummy data on first boot. The DDL +
   seed already exists at `source/ddl/01_create_and_seed.sql` (idempotent, per ARCHITECTURE
   §4, with `updated_at` + indexes for incremental).
3. **Warehouse schemas.** Add an init script creating empty `bronze`, `silver`, `gold`
   schemas in `warehouse-postgres`.
4. **CSV seeds (optional alt to SQL seed):** `source/data/*.csv` — realistic sets with valid
   FKs; load via `load_csv.py` (`COPY`, truncate-then-load, idempotent).
5. **Public-API loader** (`source/loaders/load_products_api.py`): **fetch
   `https://fakestoreapi.com/products`** (or `https://dummyjson.com/products`), map fields →
   `retail.products`, **upsert on `product_id`**. Required public-API load; handle HTTP
   errors + retries; read connection from env vars, never hardcode.
6. **Verify:** `docker compose up -d`; row counts per table > 0; FKs resolve; `products`
   refreshed from the API.

## Phase 2 — Ingestion (Airbyte OSS)

Airbyte is its own stack (`abctl local install`, kind cluster) — not a compose service.
See DEPLOYMENT §5 for host networking.

1. **Install:** `abctl local install`; open the UI at `http://localhost:8000`.
2. **Source connector — Postgres:** host `host.docker.internal` (or host IP), port **5433**,
   db `retail`/`testdb`, schema `retail`, all 5 tables.
3. **Destination connector — Postgres:** same host, port **5434** (`warehouse-postgres`),
   target schema **`bronze`**. (Variant: enable MinIO + an S3/Parquet destination for the
   Parquet-lake flavor — see ARCHITECTURE §2 variant.)
4. **Full Refresh sync:** sync mode *Full Refresh | Overwrite*; run it; confirm one
   `bronze.<table>` per source table populated.
5. **Incremental sync:** switch to *Incremental | Append + Dedup*, cursor `updated_at`,
   primary key = each table's PK. Bump `updated_at` on a few source rows, re-sync, confirm
   **only changed rows** flow.
6. **Document** connection settings in `airbyte/README.md` (source/destination/sync modes,
   cursor/PK per stream) — Airbyte config isn't fully code-versioned.

## Bronze contract (do NOT violate)
Bronze is **raw**. No renames, no casts, no dedupe here — that is Silver's job. Bronze may
only add Airbyte metadata columns (`_airbyte_*`). See ARCHITECTURE §5.

## Verification
- Full refresh reloads everything; incremental moves only changed rows.
- `warehouse.bronze` has one table per source table.
- Re-running loaders/syncs is idempotent (no dupes, no FK breakage).

## Common gotchas
- Missing `updated_at` indexes → slow incremental extraction.
- Non-idempotent API load → duplicate products; upsert on `product_id`.
- Airbyte (in kind) can't reach the DB → use `host.docker.internal`/host IP + published
  ports 5433/5434, not compose service names.
- Committing DB volumes/secrets → `.gitignore` volumes; use `deploy/.env` (gitignored).

Next: `ecommerce-build-transform`.
