create schema if not exists raw;
create schema if not exists staging;

drop table if exists staging.stg_online_retail_clean;

create table staging.stg_online_retail_clean as
with typed_rows as (
    select
        nullif(trim(invoice), '')::text as invoice_no,
        nullif(trim(stock_code), '')::text as stock_code,
        nullif(trim(description), '')::text as product_description,
        case
            when trim(quantity) ~ '^-?[0-9]+$' then trim(quantity)::integer
        end as quantity,
        case
            when nullif(trim(invoice_date), '') is not null then trim(invoice_date)::timestamp
        end as invoice_ts,
        case
            when trim(price) ~ '^-?[0-9]+(\.[0-9]+)?$' then trim(price)::numeric(12, 4)
        end as unit_price,
        case
            when trim(customer_id) ~ '^[0-9]+(\.0)?$' then trim(customer_id)::numeric::integer
        end as customer_id,
        nullif(trim(country), '')::text as country,
        source_sheet,
        _loaded_at,
        _source_file
    from raw.online_retail_raw
),
deduplicated as (
    select
        *,
        row_number() over (
            partition by invoice_no, stock_code, product_description, quantity,
                         invoice_ts, unit_price, customer_id, country
            order by _loaded_at
        ) as duplicate_rank
    from typed_rows
)
select
    invoice_no,
    stock_code,
    product_description,
    quantity,
    invoice_ts,
    unit_price,
    customer_id,
    country,
    source_sheet,
    _loaded_at,
    _source_file
from deduplicated
where duplicate_rank = 1
  and invoice_no is not null
  and stock_code is not null
  and product_description is not null
  and quantity is not null
  and invoice_ts is not null
  and unit_price is not null
  and customer_id is not null
  and country is not null
  and quantity > 0
  and unit_price > 0
  and invoice_ts >= timestamp '2000-01-01';

alter table staging.stg_online_retail_clean
    alter column invoice_no set not null,
    alter column stock_code set not null,
    alter column product_description set not null,
    alter column quantity set not null,
    alter column invoice_ts set not null,
    alter column unit_price set not null,
    alter column customer_id set not null,
    alter column country set not null,
    alter column _loaded_at set not null,
    alter column _source_file set not null;

alter table staging.stg_online_retail_clean
    add constraint chk_stg_quantity_positive check (quantity > 0),
    add constraint chk_stg_unit_price_positive check (unit_price > 0),
    add constraint chk_stg_invoice_ts_range check (invoice_ts >= timestamp '2000-01-01');
