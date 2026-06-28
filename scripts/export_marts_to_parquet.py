import os
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@localhost:5432/ecommerce_analytics",
)
EXPORT_DIR = Path("exports/parquet")
MART_TABLES = ["d_dates", "d_customers", "d_products", "f_transactions"]


def human_size(size: int) -> str:
    for unit in ["B", "KB", "MB", "GB"]:
        if size < 1024:
            return f"{size:.2f} {unit}"
        size /= 1024
    return f"{size:.2f} TB"


def main() -> None:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    engine = create_engine(DATABASE_URL)

    rows = []
    for table in MART_TABLES:
        df = pd.read_sql_table(table, con=engine, schema="marts")
        output = EXPORT_DIR / f"{table}.parquet"
        df.to_parquet(output, index=False, compression="snappy")
        rows.append(
            {
                "table": f"marts.{table}",
                "rows": len(df),
                "parquet_file": str(output),
                "parquet_size": human_size(output.stat().st_size),
            }
        )

    report = pd.DataFrame(rows)
    print(report.to_markdown(index=False))


if __name__ == "__main__":
    main()
