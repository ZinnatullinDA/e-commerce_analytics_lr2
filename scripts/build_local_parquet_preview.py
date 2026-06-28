from pathlib import Path

import pandas as pd


SOURCE_FILE = Path("online_retail_II.xlsx")
EXPORT_DIR = Path("exports/parquet_preview")


def human_size(size: int) -> str:
    for unit in ["B", "KB", "MB", "GB"]:
        if size < 1024:
            return f"{size:.2f} {unit}"
        size /= 1024
    return f"{size:.2f} TB"


def read_source() -> pd.DataFrame:
    frames = []
    excel = pd.ExcelFile(SOURCE_FILE)
    loaded_at = pd.Timestamp.now("UTC").tz_localize(None)

    for sheet_name in excel.sheet_names:
        df = pd.read_excel(SOURCE_FILE, sheet_name=sheet_name)
        df = df.rename(
            columns={
                "Invoice": "invoice_no",
                "StockCode": "stock_code",
                "Description": "product_description",
                "Quantity": "quantity",
                "InvoiceDate": "invoice_ts",
                "Price": "unit_price",
                "Customer ID": "customer_id",
                "Country": "country",
            }
        )
        df["source_sheet"] = sheet_name
        df["_loaded_at"] = loaded_at
        df["_source_file"] = SOURCE_FILE.name
        frames.append(df)

    return pd.concat(frames, ignore_index=True)


def clean_source(df: pd.DataFrame) -> pd.DataFrame:
    df = df.drop_duplicates(
        subset=[
            "invoice_no",
            "stock_code",
            "product_description",
            "quantity",
            "invoice_ts",
            "unit_price",
            "customer_id",
            "country",
        ]
    )
    df = df.dropna(
        subset=[
            "invoice_no",
            "stock_code",
            "product_description",
            "quantity",
            "invoice_ts",
            "unit_price",
            "customer_id",
            "country",
        ]
    )
    df = df[(df["quantity"] > 0) & (df["unit_price"] > 0)]
    df = df[df["invoice_ts"] >= pd.Timestamp("2000-01-01")]
    df["invoice_no"] = df["invoice_no"].astype(str)
    df["stock_code"] = df["stock_code"].astype(str)
    df["product_description"] = df["product_description"].astype(str)
    df["country"] = df["country"].astype(str)
    df["customer_id"] = df["customer_id"].astype(int)
    return df.copy()


def build_marts(clean: pd.DataFrame) -> dict[str, pd.DataFrame]:
    dates = pd.DataFrame(
        {
            "full_date": pd.date_range(
                clean["invoice_ts"].dt.date.min(),
                clean["invoice_ts"].dt.date.max(),
                freq="D",
            )
        }
    )
    dates["date_id"] = dates["full_date"].dt.strftime("%Y%m%d").astype(int)
    dates["year"] = dates["full_date"].dt.year.astype("int16")
    dates["quarter"] = dates["full_date"].dt.quarter.astype("int16")
    dates["month"] = dates["full_date"].dt.month.astype("int16")
    dates["day"] = dates["full_date"].dt.day.astype("int16")
    dates["week"] = dates["full_date"].dt.isocalendar().week.astype("int16")
    dates["_loaded_at"] = pd.Timestamp.now("UTC").tz_localize(None)
    dates["_source_file"] = "calendar"
    d_dates = dates[
        ["date_id", "full_date", "year", "quarter", "month", "day", "week", "_loaded_at", "_source_file"]
    ]

    d_customers = (
        clean.groupby(["customer_id", "country"], as_index=False)
        .agg(first_invoice_date=("invoice_ts", "min"), _loaded_at=("_loaded_at", "min"), _source_file=("_source_file", "min"))
        .rename(columns={"country": "country_name"})
    )
    d_customers["first_invoice_date"] = d_customers["first_invoice_date"].dt.date

    d_products = (
        clean.sort_values("invoice_ts")
        .drop_duplicates("stock_code", keep="last")
        .reset_index(drop=True)
    )
    d_products["product_id"] = d_products.index + 1
    d_products = d_products[
        ["product_id", "stock_code", "product_description", "_loaded_at", "_source_file"]
    ]

    product_ids = d_products[["product_id", "stock_code"]]
    f_transactions = clean.merge(product_ids, on="stock_code", how="inner")
    f_transactions = f_transactions.reset_index(drop=True)
    f_transactions["transaction_id"] = f_transactions.index + 1
    f_transactions["date_id"] = f_transactions["invoice_ts"].dt.strftime("%Y%m%d").astype(int)
    f_transactions["revenue"] = f_transactions["quantity"] * f_transactions["unit_price"]
    f_transactions = f_transactions[
        [
            "transaction_id",
            "invoice_no",
            "customer_id",
            "product_id",
            "date_id",
            "quantity",
            "unit_price",
            "revenue",
            "_loaded_at",
            "_source_file",
        ]
    ]

    return {
        "d_dates": d_dates,
        "d_customers": d_customers,
        "d_products": d_products,
        "f_transactions": f_transactions,
    }


def main() -> None:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)

    raw = read_source()
    clean = clean_source(raw)
    marts = build_marts(clean)

    rows = [
        {
            "file": str(SOURCE_FILE),
            "rows": len(raw),
            "size": human_size(SOURCE_FILE.stat().st_size),
        }
    ]

    for name, df in marts.items():
        output = EXPORT_DIR / f"{name}.parquet"
        df.to_parquet(output, index=False, compression="snappy")
        rows.append({"file": str(output), "rows": len(df), "size": human_size(output.stat().st_size)})

    print(pd.DataFrame(rows).to_markdown(index=False))


if __name__ == "__main__":
    main()
