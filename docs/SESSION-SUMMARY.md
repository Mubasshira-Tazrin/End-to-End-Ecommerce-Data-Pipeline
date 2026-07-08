# Retail Analytics Data Platform — Build Session Summary

_Last updated: 2026-07-07_

A running log of the POC build: the plan, what was done step by step, every error hit and how it was solved, and what's next. Companion to `design/ARCHITECTURE.md` and `design/DEPLOYMENT.md`.

---

## 1. Project overview

**Objective:** Build an end-to-end Retail Analytics data platform — ingest from a source database, transform through a Medallion (Bronze → Silver → Gold) architecture, orchestrate with Airflow, and serve business insights via a dashboard.

**Nature:** Proof of Concept (POC), built for learning, on a single laptop.

**Source spec:** `project description.txt` (10 phases).

### Key decisions
| Decision | Choice | Reason |
|---|---|---|
| Deployment | **Everything in Docker EXCEPT Databricks** | Databricks is a managed cloud service — can't be containerized; kept as real cloud |
| Databricks edition | **Free Edition** | Has Unity Catalog + serverless SQL warehouse + Volumes (Community Edition lacks these) |
| Reporting tool | Metabase (Docker); Power BI optional external | Power BI Desktop can't run in a container |
| Skills structure | 4 consolidated lifecycle skills under `.claude/skills/ecommerce-*` | Grouped by project phase |

---

## 2. Architecture

```
┌─────────────── Docker (laptop) ───────────────┐        ☁ Databricks Cloud
│                                                │        (NOT dockerized)
│  source-postgres ──► Airbyte OSS ──────────────┼──────► Bronze (retail.raw)  [Delta]
│                                                │           │  dbt-databricks
│  dbt container ────────────────────────────────┼───────► Silver ─► Gold [Delta]
│                                                │                     │
│  (later: Airflow, Metabase)  ◄─────────────────┼─────────────────────┘
└────────────────────────────────────────────────┘
```

- **In Docker:** source Postgres, Airbyte (via abctl/kind cluster), dbt (tool container). Later: Airflow + Cosmos, Metabase.
- **In the cloud:** Databricks lakehouse (Bronze/Silver/Gold as Delta tables in Unity Catalog).
- All Docker services connect **outbound** to Databricks — no inbound needed.

### Tech stack (spec → local substitution)
| Spec | This POC |
|---|---|
| PostgreSQL source | `source-postgres` container (auto-seeded) |
| Airbyte → Databricks | Airbyte OSS (abctl) → Databricks Bronze |
| Databricks Medallion | **Real Databricks Free Edition** (`retail` catalog) |
| dbt | dbt-databricks (in a Docker container) |
| Airflow + Cosmos | Airflow + astronomer-cosmos (Docker) — _pending_ |
| GitLab CI/CD | Git + `.gitlab-ci.yml` — _pending_ |
| Data Quality | dbt tests + reconciliation — _pending_ |
| Power BI | Metabase (Docker) — _pending_ |

---

## 3. Progress by phase

| Phase | Status |
|---|---|
| 1. Source setup (Postgres + data) | ✅ **Complete** |
| 2. Ingestion (Airbyte → Bronze, full + incremental) | ✅ **Complete** |
| 3-4. dbt Medallion (Silver + Gold) | 🔄 **In progress** (dbt Docker setup) |
| 5. Airflow orchestration | ⬜ Pending |
| 6. Version control & CI/CD | ⬜ Pending |
| 7. Data quality & monitoring | ⬜ Pending |
| 8. Reporting (dashboard) | ⬜ Pending |
| 9. Documentation | ⬜ Pending |
| 10. Final presentation | ⬜ Pending |

---

## 4. Step-by-step log (with errors & solutions)

### Phase 1 — Source Postgres in Docker ✅
- Wrote `source/ddl/01_create_and_seed.sql`: schema `retail`, 5 tables (customers, products, orders, order_items, payments) with `updated_at` columns + indexes, and dummy data (200 customers, 60 products, 500 orders, 2000 order_items, 500 payments). Idempotent.
- Created `deploy/docker-compose.yml` (`source-postgres`, postgres:16, host port **5433**) and `deploy/.env`.
- The DDL is mounted into `/docker-entrypoint-initdb.d/` so the DB **self-seeds on first boot**.
- **Verified:** all row counts correct; `orders.total_amount` = sum of line items (0 mismatches).

### Phase 2 — Airbyte ingestion ✅

**Docker install**
- Installed Docker Engine + Compose on Ubuntu 24.04.
- ❌ **Error:** `docker-ce has no installation candidate` → **Cause:** the Docker apt repo never registered (multi-line paste mangled the repo file). **Fix:** re-added the repo as a single line with `noble` hardcoded, `apt-get update`, then install.
- ❌ **Error:** `permission denied ... /var/run/docker.sock` → **Fix:** `sudo usermod -aG docker $USER` + `newgrp docker` (run Docker without sudo).

**Airbyte install (abctl)**
- Installed `abctl`, ran `abctl local install` (creates a kind Kubernetes cluster in Docker).
- ❌ **Error:** `pod airbyte-abctl-bootloader failed: Failed to fetch remote connector registry ... timeout` → **Cause:** transient network timeout downloading the 4.8 MB connector registry (30s budget). **Fix:** `abctl local uninstall` + re-install (connection was fine on retry).
- ❌ **Error:** `pgdata/PG_VERSION: permission denied` on reinstall → **Cause:** leftover data dir from the failed install, owned by container UID 70. **Fix:** `sudo rm -rf ~/.airbyte/abctl/data` then reinstall. **Succeeded.**

**Postgres → Databricks connection**
- **Source (Postgres):** host **`172.19.0.1`** (the kind-network gateway IP — NOT localhost/host.docker.internal, which don't resolve from inside the cluster), port 5433.
  - ❌ **Error:** `The server does not support SSL` → **Fix:** set SSL Mode = **`disable`** (plain postgres image has no TLS).
- **Destination (Databricks Lakehouse v4.0.0):** the hard part.
  - ❌ **Error:** `auth_type=pat ... cannot configure default credentials` (repeated, even with a valid token) → **Cause:** the Databricks Lakehouse connector's **PAT auth is broken on Free Edition**. **Fix:** switched to **OAuth2 M2M with a service principal**.
    - Created service principal `airbyte-sp` in Databricks → got **Application ID** (= Client ID) + generated **OAuth Secret** (= Client Secret).
    - Set the destination's Auth type = OAuth2, Client ID + Secret.
  - ❌ **Error:** `PERMISSION_DENIED: User does not have USE CATALOG on Catalog 'retail'` → **Cause:** service principal lacked catalog grants. **Fix:** `GRANT ALL PRIVILEGES ON CATALOG retail TO \`<application-id>\`;` + gave `airbyte-sp` "Can use" on the SQL warehouse.
  - **Destination saved ✅.**

**First sync + verify**
- Created connection, ran first sync (Full Refresh | Overwrite).
- Appeared "stuck" on Queued → actually just **downloading a 487 MB orchestrator image** on first run (~1.5 min). Not stuck.
- ❌ **Error (in Databricks):** `User does not have USE SCHEMA on Schema 'retail.retail'` → **Cause 1:** connection defaulted to **"Mirror source structure"**, so data landed in `retail.retail` (source schema name mirrored). **Cause 2:** the SP created/owns that schema, so the human user lacked read access.
  - **Fix:** switched Destination Namespace to **Custom format = `raw`** (data now lands in `retail.raw.*`); granted the user `USE SCHEMA, SELECT`; dropped the stale schema with `DROP SCHEMA retail.retail CASCADE`.
- **Bronze confirmed** in `retail.raw.*` (200 customers, 500 orders, etc.).

**Incremental sync**
- Switched all streams to **Incremental | Append + Dedup**:
  - customers/products/orders/payments → cursor `updated_at`, PK = table PK.
  - **order_items** → cursor **`order_item_id`** (it has no `updated_at`; its serial id is strictly increasing).
- **Verified:** bumping a few source rows' `updated_at` and re-syncing moved **only the changed rows**. ✅ Phase 2 complete.

**Concepts clarified along the way**
- **Unity Catalog Volumes** = Airbyte's staging area for the Databricks connector (writes files to a volume, then `COPY INTO` the Delta table). The `raw<stream><hash>` volumes are per-stream staging (keep them); `_airbyte_check_*` volumes are leftovers from "Test the destination" clicks (harmless, deletable).
- Connector **v4.0.0 has no `airbyte_internal` schema option** — staging volumes live in the same schema as the tables. **v3.3.8 offers a dedicated `airbyte_internal` schema** (cleaner) — flagged to revisit later.
- Airbyte's own `abctl local credentials` (email/password + client-id/secret) are for the **Airbyte UI/API** — NOT the Databricks OAuth creds. Don't confuse them.

### Phase 3-4 — dbt on Databricks 🔄 (in progress)
- **Decision:** dbt runs in a Docker container (matching "everything dockerized"); Databricks stays cloud — the dbt container connects **out** to it.
- Files created so far:
  - `deploy/dbt/Dockerfile` — Python + `dbt-databricks`, entrypoint `dbt`.
  - `dbt/profiles.yml` — connection via env vars, **OAuth M2M** (reuses `airbyte-sp`).
  - `dbt/retail/dbt_project.yml` — medallion layout (`staging` → silver, `marts` → gold).
- **Pending file:** `dbt/retail/macros/generate_schema_name.sql` — needed so schema names come out **exactly** `silver`/`gold` (dbt otherwise concatenates to `silver_gold`). _Discussion in progress._
- **Pending:** add the `dbt` service to `deploy/docker-compose.yml`, add `DBX_*` vars to `.env`, then build + `dbt debug`.

---

## 5. Current state / where we are
- Postgres (Docker) ✅ running & seeded.
- Airbyte (Docker) ✅ syncing Postgres → Databricks `retail.raw` (Bronze), incremental working.
- dbt-in-Docker setup **partially scaffolded**; not yet connected (`dbt debug` not yet run).
- The last action (adding the dbt service to docker-compose) was paused to write this summary.

---

## 6. Next steps

1. **Finish dbt Docker setup:**
   - Create `dbt/retail/macros/generate_schema_name.sql` (clean `silver`/`gold` names).
   - Add the `dbt` service to `deploy/docker-compose.yml` (build context `./dbt`, mount `../dbt`, `DBX_*` env vars, compose profile `tools`).
   - Add Databricks connection values to `deploy/.env`: `DBX_HOST`, `DBX_HTTP_PATH`, `DBX_CATALOG=retail`, `DBX_CLIENT_ID`, `DBX_CLIENT_SECRET` (the `airbyte-sp` OAuth creds).
   - Build + test: `docker compose build dbt` then `docker compose run --rm dbt debug` → expect "All checks passed".
2. **Declare Bronze as dbt sources** (`retail.raw.*`).
3. **Build Silver** staging models (`stg_*`): dedupe on PK+`updated_at`, null handling, type casts, standardization.
4. **Build Gold** star schema: `dim_customer`, `dim_product`, `dim_date`, `fact_sales` (line-item grain).
5. **Add dbt tests + docs** (unique, not_null, relationships, accepted_values; `dbt docs generate`).
6. Then Phase 5 (Airflow + Cosmos orchestration), Phase 7 (data quality/monitoring), Phase 8 (Metabase dashboard), Phase 9-10 (docs + presentation).

---

## 7. Handy reference

**Connection facts**
- Source Postgres (from host): `psql -d testdb` or the container `retail`/`retail_pw` on host port **5433**.
- Airbyte reaches Postgres at **`172.19.0.1:5433`**, SSL `disable`.
- Databricks: catalog **`retail`**, Bronze schema **`raw`**; auth via **`airbyte-sp`** service principal (OAuth M2M).

**Common commands**
```bash
# Postgres
cd deploy && docker compose up -d
docker exec retail-source-postgres psql -U retail -d retail -c "\dt retail.*"

# Airbyte
abctl local install
abctl local credentials          # Airbyte UI login (NOT Databricks)

# dbt (once set up)
docker compose build dbt
docker compose run --rm dbt debug
docker compose run --rm dbt run
```

**Gotchas cheat-sheet**
- Airbyte→Postgres: use gateway IP `172.19.0.1`, not localhost; SSL `disable`.
- Airbyte→Databricks: PAT auth broken on Free Edition → use OAuth service principal + `GRANT ALL PRIVILEGES ON CATALOG`.
- dbt schema names: need the `generate_schema_name` macro or dbt concatenates them.
