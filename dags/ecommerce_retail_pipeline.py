from __future__ import annotations

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG


PROJECT_DIR = "/opt/airflow/project"


with DAG(
    dag_id="ecommerce_retail_analytics_pipeline",
    description="Build Online Retail analytical marts and export them to Parquet.",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    tags=["ecommerce", "retail", "etl", "lab2"],
) as dag:
    profile_source = BashOperator(
        task_id="profile_source",
        bash_command=f"cd {PROJECT_DIR} && python scripts/profile_source.py",
    )

    load_raw = BashOperator(
        task_id="load_raw",
        bash_command=f"cd {PROJECT_DIR} && python scripts/load_raw.py",
    )

    build_sql_layers = BashOperator(
        task_id="build_sql_layers",
        bash_command=f"cd {PROJECT_DIR} && python scripts/run_sql.py",
    )

    export_marts_to_parquet = BashOperator(
        task_id="export_marts_to_parquet",
        bash_command=f"cd {PROJECT_DIR} && python scripts/export_marts_to_parquet.py",
    )

    profile_source >> load_raw >> build_sql_layers >> export_marts_to_parquet
