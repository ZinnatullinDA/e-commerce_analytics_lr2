import os
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@localhost:5432/ecommerce_analytics",
)
SOURCE_FILE = Path(os.getenv("SOURCE_FILE", "online_retail_II.xlsx"))


def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    return df.rename(
        columns={
            "Invoice": "invoice",
            "StockCode": "stock_code",
            "Description": "description",
            "Quantity": "quantity",
            "InvoiceDate": "invoice_date",
            "Price": "price",
            "Customer ID": "customer_id",
            "Country": "country",
        }
    )


def main() -> None:
    if not SOURCE_FILE.exists():
        raise FileNotFoundError(f"Source file not found: {SOURCE_FILE}")

    engine = create_engine(DATABASE_URL)
    with engine.begin() as conn:
        conn.execute(text("create schema if not exists raw"))
        conn.execute(text("drop table if exists raw.online_retail_raw"))

    excel = pd.ExcelFile(SOURCE_FILE)
    loaded_at = pd.Timestamp.now("UTC").tz_localize(None)

    for index, sheet_name in enumerate(excel.sheet_names):
        df = pd.read_excel(SOURCE_FILE, sheet_name=sheet_name, dtype=str)
        df = normalize_columns(df)
        df["source_sheet"] = sheet_name
        df["_loaded_at"] = loaded_at
        df["_source_file"] = SOURCE_FILE.name

        df.to_sql(
            "online_retail_raw",
            con=engine,
            schema="raw",
            if_exists="replace" if index == 0 else "append",
            index=False,
            chunksize=10_000,
            method="multi",
        )

    print(f"Loaded {SOURCE_FILE.name} into raw.online_retail_raw")


if __name__ == "__main__":
    main()
