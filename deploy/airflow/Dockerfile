# Start FROM the official Airflow image (Airflow 2.10.3 on Python 3.11).
FROM apache/airflow:2.10.3-python3.11

# Become admin to install system software.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git \
    && rm -rf /var/lib/apt/lists/*
# Drop back to the safe, normal user.
USER airflow

# Airflow's own tools: Cosmos (runs dbt as Airflow tasks) + the Airbyte connector.
RUN pip install --no-cache-dir \
    "astronomer-cosmos==1.7.1" \
    "apache-airflow-providers-airbyte" \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.10.3/constraints-3.11.txt"

# dbt in its own isolated venv (so its libraries never clash with Airflow's).
RUN python -m venv /home/airflow/dbt_venv \
    && /home/airflow/dbt_venv/bin/pip install --no-cache-dir "dbt-databricks"
