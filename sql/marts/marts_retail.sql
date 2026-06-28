create schema if not exists marts;

drop table if exists marts.f_transactions cascade;
drop table if exists marts.d_products cascade;
drop table if exists marts.d_customers cascade;
drop table if exists marts.d_dates cascade;

create table marts.d_dates (
    date_id integer primary key,
    full_date date not null unique,
    year smallint not null,
    quarter smallint not null,
    month smallint not null,
    day smallint not null,
    week smallint not null,
    _loaded_at timestamp not null default now(),
    _source_file text not null,
    constraint chk_d_dates_range check (full_date >= date '2000-01-01')
);

insert into marts.d_dates (
    date_id, full_date, year, quarter, month, day, week, _loaded_at, _source_file
)
select
    to_char(d::date, 'YYYYMMDD')::integer as date_id,
    d::date as full_date,
    extract(year from d)::smallint as year,
    extract(quarter from d)::smallint as quarter,
    extract(month from d)::smallint as month,
    extract(day from d)::smallint as day,
    extract(week from d)::smallint as week,
    now(),
    'calendar'
from generate_series(
    (select min(invoice_ts)::date from ods.invoices),
    (select max(invoice_ts)::date from ods.invoices),
    interval '1 day'
) as d;

create table marts.d_customers (
    customer_id integer primary key,
    country_name text not null,
    first_invoice_date date not null,
    _loaded_at timestamp not null default now(),
    _source_file text not null,
    constraint chk_d_customers_first_invoice_date check (first_invoice_date >= date '2000-01-01')
);

insert into marts.d_customers (customer_id, country_name, first_invoice_date, _loaded_at, _source_file)
select
    c.customer_id,
    co.country_name,
    min(i.invoice_ts)::date as first_invoice_date,
    min(c._loaded_at),
    min(c._source_file)
from ods.customers c
join ods.countries co on co.country_id = c.country_id
join ods.invoices i on i.customer_id = c.customer_id
group by c.customer_id, co.country_name;

create table marts.d_products (
    product_id integer primary key,
    stock_code text not null unique,
    product_description text not null,
    _loaded_at timestamp not null default now(),
    _source_file text not null
);

insert into marts.d_products (product_id, stock_code, product_description, _loaded_at, _source_file)
select product_id, stock_code, product_description, _loaded_at, _source_file
from ods.products;

create table marts.f_transactions (
    transaction_id bigint primary key,
    invoice_no text not null,
    customer_id integer not null references marts.d_customers(customer_id),
    product_id integer not null references marts.d_products(product_id),
    date_id integer not null references marts.d_dates(date_id),
    quantity integer not null,
    unit_price numeric(12, 4) not null,
    revenue numeric(14, 4) not null,
    _loaded_at timestamp not null default now(),
    _source_file text not null,
    constraint chk_f_transactions_quantity_positive check (quantity > 0),
    constraint chk_f_transactions_unit_price_positive check (unit_price > 0),
    constraint chk_f_transactions_revenue_positive check (revenue > 0)
);

insert into marts.f_transactions (
    transaction_id,
    invoice_no,
    customer_id,
    product_id,
    date_id,
    quantity,
    unit_price,
    revenue,
    _loaded_at,
    _source_file
)
select
    il.invoice_line_id as transaction_id,
    i.invoice_no,
    i.customer_id,
    il.product_id,
    to_char(i.invoice_ts::date, 'YYYYMMDD')::integer as date_id,
    il.quantity,
    il.unit_price,
    il.line_amount as revenue,
    il._loaded_at,
    il._source_file
from ods.invoice_lines il
join ods.invoices i on i.invoice_no = il.invoice_no;
