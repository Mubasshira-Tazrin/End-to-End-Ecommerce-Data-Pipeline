---
name: ecommerce-report-document
description: >-
  Deliver reporting, documentation, and the final presentation for the Retail Analytics
  POC (spec phases 8-10). Use when building the BI dashboard on the Gold layer (Total
  Sales, Total Orders, Total Customers, Sales Trend, Product Performance) in Power BI
  Desktop or Metabase, writing project documentation (architecture diagram, setup guide,
  data dictionary, runbook), or preparing the final presentation. Triggers: "power bi",
  "dashboard", "metabase", "reporting", "kpi cards", "sales trend", "documentation",
  "data dictionary", "runbook", "setup guide", "presentation".
---

# Report & Document — BI, Docs, Presentation (Phases 8-10)

Read `design/ARCHITECTURE.md` §9-§10 first. The dashboard reads **Gold only**.
Before writing any chart, follow the `dataviz` skill for palette/layout/accessibility.

## Deliverables checklist
- [ ] Dashboard: Total Sales, Total Orders, Total Customers, Sales Trend, Product Performance
- [ ] Architecture diagram (mermaid in ARCHITECTURE + an exported image)
- [ ] Setup guide (`docs/setup-guide.md`)
- [ ] Data dictionary (`docs/data-dictionary.md`)
- [ ] Runbook (`docs/runbook.md`)
- [ ] Final presentation outline (`docs/presentation.md`)

## Phase 8 — Reporting

1. **Connect BI to Gold:**
   - **Metabase** (primary, containerized): the `metabase` service is already in
     `deploy/docker-compose.yml`. In the setup wizard, add a **Postgres** database pointing
     at `warehouse-postgres:5432`, schema **`gold`**. Fully in Docker — no ODBC/drivers.
   - **Power BI Desktop** (optional, external): connect its Postgres connector to the
     warehouse host port **5434**, import the `gold` tables. Runs outside Docker (Windows).
2. **Model:** relate `fact_sales` to `dim_customer`, `dim_product`, `dim_date` (star).
3. **Pages / visuals:**
   - KPI cards: **Total Sales** `sum(line_amount)`, **Total Orders**
     `distinct order_id`, **Total Customers** `distinct customer_id`.
   - **Sales Trend:** line chart of sales by month from `dim_date`.
   - **Product Performance:** bar of sales by product / category (top N).
   - Add a date + category slicer. Apply `dataviz` color and label guidance.
4. **Persist** the Metabase dashboard (its app state lives in the `mb-data` volume); export
   the dashboard/questions and store screenshots under `reporting/`. If using Power BI, save
   `.pbix` there too (binary — commit the export + screenshots).

## Phase 9 — Documentation

1. **Architecture diagram:** already in `design/ARCHITECTURE.md` (mermaid §3); export a PNG
   into `docs/` for the presentation.
2. **Setup guide (`docs/setup-guide.md`):** clone → `.env` → start Postgres → load data →
   start Airbyte + configure syncs → `dbt build` → start Airflow → run DAG → connect BI.
   Copy-pasteable commands; list prerequisites and ports.
3. **Data dictionary (`docs/data-dictionary.md`):** source tables (§4) + every Gold
   table/column with type + description; link to `dbt docs`.
4. **Runbook (`docs/runbook.md`):** how to run the pipeline, the monitoring guide pointers,
   common failures + fixes, how to backfill/re-sync, how to recover from a failed DAG run.

## Phase 10 — Final presentation (`docs/presentation.md`)
Outline covering: Solution Architecture, Data Flow, Airbyte pipeline, dbt models, Airflow
orchestration, Data Quality strategy, Dashboard walkthrough, Key Learnings & challenges.

## Common gotchas
- Dashboard querying Silver/Bronze — it must read Gold only.
- Power BI import mode going stale — refresh after each pipeline run (or use DirectQuery).
- Data dictionary drifting from models — regenerate from `dbt docs` when models change.
- `.pbix` diffs are unreadable in Git — commit screenshots/exports alongside.

Prev: `ecommerce-orchestrate-operate`.
