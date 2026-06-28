import os
from pathlib import Path

from sqlalchemy import create_engine, text


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@localhost:5432/ecommerce_analytics",
)

SQL_FILES = [
    Path("sql/staging/stg_online_retail.sql"),
    Path("sql/ods/ods_retail.sql"),
    Path("sql/marts/marts_retail.sql"),
]


def main() -> None:
    engine = create_engine(DATABASE_URL)
    with engine.begin() as conn:
        for sql_file in SQL_FILES:
            print(f"Running {sql_file}")
            conn.execute(text(sql_file.read_text(encoding="utf-8")))

    print("SQL pipeline finished")


if __name__ == "__main__":
    main()
