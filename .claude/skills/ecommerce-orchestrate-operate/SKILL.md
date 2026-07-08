---
name: ecommerce-orchestrate-operate
description: >-
  Orchestrate and operate the Retail Analytics POC pipeline (spec phases 5-7). Use when
  setting up Airflow with astronomer-cosmos, building the orchestration DAG
  (airbyte_sync → dbt_silver → dbt_gold → dq checks), configuring Git/GitLab CI-CD with
  feature branches and merge requests, or implementing the data quality framework (row
  count, duplicate, null, source-vs-target reconciliation) and the monitoring guide for
  Airflow/Airbyte/dbt logs. Triggers: "airflow", "cosmos", "orchestration dag", "ci/cd",
  "gitlab", "data quality", "reconciliation", "monitoring", "row count check".
---

# Orchestrate & Operate — Airflow, CI/CD, Data Quality (Phases 5-7)

Read `design/ARCHITECTURE.md` §6-§8 first.

## Deliverables checklist
- [ ] Airflow running (Docker) with astronomer-cosmos
- [ ] DAG `retail_pipeline`: airbyte_sync → dbt_silver → dbt_gold → dq_reconciliation
- [ ] Git repo with feature-branch + merge-request workflow
- [ ] `.gitlab-ci.yml`: lint → compile → test, gating MRs
- [ ] Data quality framework (4 required checks) implemented
- [ ] Monitoring guide (where/how to read Airflow, Airbyte, dbt logs)

## Phase 5 — Airflow + Cosmos

1. **Airflow via Docker** (in `deploy/docker-compose.yml`, LocalExecutor is fine for POC;
   custom image at `deploy/airflow/Dockerfile`). Install
   `apache-airflow-providers-airbyte`, `astronomer-cosmos`, and `dbt-postgres`. Cosmos points
   at `warehouse-postgres` via the env-based dbt profile (see DEPLOYMENT §2).
2. **DAG `airflow/dags/retail_pipeline.py`:**
   - `airbyte_sync` = `AirbyteTriggerSyncOperator` (connection_id from an Airbyte
     connection; `asynchronous=False` so it waits).
   - `dbt_silver`, `dbt_gold` = Cosmos `DbtTaskGroup`s selecting `tag:silver` / `tag:gold`.
   - `dq_reconciliation` = the Phase-7 reconciliation task (below).
   - Wire: `airbyte_sync >> dbt_silver >> dbt_gold >> dq_reconciliation`.
   - Set retries, `retry_delay`, and a failure callback for alerting.
3. **Verify:** trigger the DAG; all tasks green; Gold refreshes; DQ passes. Break a source
   row on purpose and confirm the DAG **fails loudly** at the right task.

## Phase 6 — Version control & CI/CD (GitLab)

1. `git init`; sensible `.gitignore` (DB volumes, `deploy/.env`, airflow logs,
   dbt `target/`, `dbt_packages/`).
2. **Workflow:** protected `main`; do work on `feature/*` branches; land via **merge
   requests** with the CI gate green.
3. **`.gitlab-ci.yml`** stages:
   - `lint`: `sqlfluff lint dbt/retail/models`.
   - `compile`: `dbt deps && dbt parse` (catches ref/config errors, no warehouse needed).
   - `test`: `dbt build --target ci` against an **ephemeral Postgres service** (GitLab CI
     `services:`) seeded with small fixtures, then `dbt test`. Fail the pipeline on any
     test failure.
   - Cache `dbt_packages/`; run in a Python image with the project installed.

## Phase 7 — Data quality & monitoring

Map the **four required checks** to concrete implementations:
| Required check           | Implementation                                                   |
|--------------------------|------------------------------------------------------------------|
| Row count validation     | `dbt_expectations.expect_table_row_count_to_be_between` per model |
| Duplicate checks         | `unique` tests on all PKs/SKs (+ combos where grain demands)      |
| Null checks              | `not_null` tests on required columns                             |
| Source vs target reconciliation | `quality/reconcile.py` (below) run as the DAG's `dq_reconciliation` task |

1. **`quality/reconcile.py`:** for each entity compare **`source-postgres`** row counts and
   key aggregate sums (e.g. `sum(amount)` payments, count of orders) against the **`gold`**
   schema in `warehouse-postgres`; exit non-zero on mismatch beyond tolerance; write a
   summary to the log.
2. **Monitoring guide** (`docs/monitoring.md`):
   - **Airflow:** UI Grid/Graph, per-task logs, where log files live, how retries surface.
   - **Airbyte:** connection sync history + per-attempt logs in the UI.
   - **dbt:** `target/run_results.json`, `logs/dbt.log`, and test failure output.
   - What "healthy" looks like and the first thing to check on each failure type.

## Common gotchas
- Cosmos can't find the dbt profile → set `ProfileConfig`/`profiles.yml` path explicitly.
- Airbyte connection_id hardcoded → store as an Airflow Variable/Connection.
- CI hitting the real lake → CI must use isolated seed fixtures, never prod paths.
- Reconciliation comparing raw floats → round / use tolerance to avoid false alarms.

Prev: `ecommerce-build-transform`. Next: `ecommerce-report-document`.
