# dbt runtime for the Retail POC — targets Databricks (Delta / Unity Catalog).
FROM python:3.11-slim

# git is needed by `dbt deps` to fetch packages (dbt_utils, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "dbt-databricks"

# project is bind-mounted here at run time (see docker-compose.yml)
WORKDIR /workspace/dbt/retail
ENV DBT_PROFILES_DIR=/workspace/dbt

ENTRYPOINT ["dbt"]
