from datetime import datetime

from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.providers.airbyte.operators.airbyte import AirbyteTriggerSyncOperator
from cosmos import DbtTaskGroup, ExecutionConfig, ProfileConfig, ProjectConfig, RenderConfig

DBT_PROJECT_DIR = "/opt/airflow/dbt/retail"
DBT_PROFILES_DIR = "/opt/airflow/dbt"
DBT_EXECUTABLE = "/home/airflow/dbt_venv/bin/dbt"

profile_config = ProfileConfig(
    profile_name="retail",
    target_name="dev",
    profiles_yml_filepath=f"{DBT_PROFILES_DIR}/profiles.yml",
)

execution_config = ExecutionConfig(
    dbt_executable_path=DBT_EXECUTABLE,
)

with DAG(
    dag_id="retail_pipeline",
    description="Airbyte sync -> dbt Silver -> dbt Gold -> DQ reconciliation",
    start_date=datetime(2026, 1, 1),
    schedule=None,          # manual trigger for now; add a cron once it's proven stable
    catchup=False,
    default_args={"retries": 1},
    tags=["retail", "medallion"],
) as dag:

    airbyte_sync = AirbyteTriggerSyncOperator(
        task_id="airbyte_sync",
        airbyte_conn_id="airbyte_default",
        connection_id="{{ var.value.airbyte_connection_id }}",
        asynchronous=False,
        timeout=3600,
        wait_seconds=10,
    )

    dbt_silver = DbtTaskGroup(
        group_id="dbt_silver",
        project_config=ProjectConfig(DBT_PROJECT_DIR),
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=RenderConfig(select=["tag:silver"]),
    )

    dbt_gold = DbtTaskGroup(
        group_id="dbt_gold",
        project_config=ProjectConfig(DBT_PROJECT_DIR),
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=RenderConfig(select=["tag:gold"]),
    )

    # TODO (Phase 7): replace with quality/reconcile.py — source-vs-target checks
    dq_reconciliation = EmptyOperator(task_id="dq_reconciliation")

    airbyte_sync >> dbt_silver >> dbt_gold >> dq_reconciliation
