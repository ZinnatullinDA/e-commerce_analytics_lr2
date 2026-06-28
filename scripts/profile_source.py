from pathlib import Path

import pandas as pd


SOURCE_FILE = Path("online_retail_II.xlsx")


def main() -> None:
    excel = pd.ExcelFile(SOURCE_FILE)
    rows = []
    for sheet_name in excel.sheet_names:
        df = pd.read_excel(SOURCE_FILE, sheet_name=sheet_name)
        rows.append(
            {
                "sheet": sheet_name,
                "rows": len(df),
                "duplicates": int(df.duplicated().sum()),
                "missing_customer_id": int(df["Customer ID"].isna().sum()),
                "missing_description": int(df["Description"].isna().sum()),
                "date_min": df["InvoiceDate"].min(),
                "date_max": df["InvoiceDate"].max(),
            }
        )

    print(pd.DataFrame(rows).to_markdown(index=False))


if __name__ == "__main__":
    main()
