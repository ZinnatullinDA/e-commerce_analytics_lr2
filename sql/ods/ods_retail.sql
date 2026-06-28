create schema if not exists ods;

drop table if exists ods.invoice_lines cascade;
drop table if exists ods.invoices cascade;
drop table if exists ods.products cascade;
drop table if exists ods.customers cascade;
drop table if exists ods.countries cascade;

create table ods.countries (
    country_id integer generated always as identity primary key,
    country_name text not null unique,
    _loaded_at timestamp not null default now(),
    _source_file text not null
);

insert into ods.countries (country_name, _loaded_at, _source_file)
select
    country,
    min(_loaded_at),
    min(_source_file)
from staging.stg_online_retail_clean
group by country;

create table ods.customers (
    customer_id integer primary key,
    country_id integer not null references ods.countries(country_id),
    _loaded_at timestamp not null default now(),
    _source_file text not null
);

insert into ods.customers (customer_id, country_id, _loaded_at, _source_file)
with customer_country_rank as (
    select
        customer_id,
        country,
        count(*) as rows_count,
        max(invoice_ts) as last_invoice_ts,
        min(_loaded_at) as first_loaded_at,
        min(_source_file) as source_file,
        row_number() over (
            partition by customer_id
            order by count(*) desc, max(invoice_ts) desc, country
        ) as rn
    from staging.stg_online_retail_clean
    group by customer_id, country
)
select
    r.customer_id,
    c.country_id,
    r.first_loaded_at,
    r.source_file
from customer_country_rank r
join ods.countries c on c.country_name = r.country
where r.rn = 1;

create table ods.products (
    product_id integer generated always as identity primary key,
    stock_code text not null unique,
    product_description text not null,
    _loaded_at timestamp not null default now(),
    _source_file text not null
);

insert into ods.products (stock_code, product_description, _loaded_at, _source_file)
select distinct on (stock_code)
    stock_code,
    product_description,
    _loaded_at,
    _source_file
from staging.stg_online_retail_clean
order by stock_code, invoice_ts desc;

create table ods.invoices (
    invoice_no text primary key,
    customer_id integer not null references ods.customers(customer_id),
    invoice_ts timestamp not null,
    _loaded_at timestamp not null default now(),
    _source_file text not null,
    constraint chk_ods_invoice_ts_range check (invoice_ts >= timestamp '2000-01-01')
);

insert into ods.invoices (invoice_no, customer_id, invoice_ts, _loaded_at, _source_file)
select
    invoice_no,
    customer_id,
    min(invoice_ts) as invoice_ts,
    min(_loaded_at),
    min(_source_file)
from staging.stg_online_retail_clean
group by invoice_no, customer_id;

create table ods.invoice_lines (
    invoice_line_id bigint generated always as identity primary key,
    invoice_no text not null references ods.invoices(invoice_no),
    product_id integer not null references ods.products(product_id),
    quantity integer not null,
    unit_price numeric(12, 4) not null,
    line_amount numeric(14, 4) generated always as (quantity * unit_price) stored,
    _loaded_at timestamp not null default now(),
    _source_file text not null,
    constraint uq_ods_invoice_line unique (invoice_no, product_id, quantity, unit_price),
    constraint chk_ods_quantity_positive check (quantity > 0),
    constraint chk_ods_unit_price_positive check (unit_price > 0),
    constraint chk_ods_line_amount_positive check (line_amount > 0)
);

insert into ods.invoice_lines (
    invoice_no,
    product_id,
    quantity,
    unit_price,
    _loaded_at,
    _source_file
)
select
    s.invoice_no,
    p.product_id,
    s.quantity,
    s.unit_price,
    min(s._loaded_at),
    min(s._source_file)
from staging.stg_online_retail_clean s
join ods.products p on p.stock_code = s.stock_code
group by s.invoice_no, p.product_id, s.quantity, s.unit_price;
