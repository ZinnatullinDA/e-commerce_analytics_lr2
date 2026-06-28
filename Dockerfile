FROM apache/airflow:3.2.1

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

USER airflow

ARG AIRFLOW_VERSION=3.2.1
ARG PYTHON_VERSION=3.13
ARG CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

RUN pip install --no-cache-dir --constraint "${CONSTRAINT_URL}" \
    apache-airflow-providers-standard \
    apache-airflow-providers-postgres

RUN pip install --no-cache-dir \
    airflow-clickhouse-plugin \
    clickhouse-connect

RUN pip install --no-cache-dir \
    psycopg \
    pymongo \
    requests \
    pydantic

COPY requirements.txt /tmp/requirements.txt

RUN pip install --no-cache-dir -r /tmp/requirements.txt
