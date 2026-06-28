-- Revenue by month.
select
    d.year,
    d.month,
    sum(f.revenue) as revenue
from marts.f_transactions f
join marts.d_dates d on d.date_id = f.date_id
group by d.year, d.month
order by d.year, d.month;

-- ARPU by month: average revenue per active customer.
select
    d.year,
    d.month,
    sum(f.revenue) / count(distinct f.customer_id) as arpu
from marts.f_transactions f
join marts.d_dates d on d.date_id = f.date_id
group by d.year, d.month
order by d.year, d.month;

-- New customers by month.
select
    extract(year from first_invoice_date)::integer as year,
    extract(month from first_invoice_date)::integer as month,
    count(*) as new_customers
from marts.d_customers
group by 1, 2
order by 1, 2;

-- Simplified retention by month:
-- share of customers with at least one purchase before the month and another purchase in the month.
with monthly_activity as (
    select distinct
        f.customer_id,
        date_trunc('month', d.full_date)::date as month_start
    from marts.f_transactions f
    join marts.d_dates d on d.date_id = f.date_id
),
customer_first_month as (
    select customer_id, min(month_start) as first_month
    from monthly_activity
    group by customer_id
)
select
    ma.month_start,
    count(*) filter (where cfm.first_month < ma.month_start)::numeric
        / nullif(count(*), 0) as retention
from monthly_activity ma
join customer_first_month cfm on cfm.customer_id = ma.customer_id
group by ma.month_start
order by ma.month_start;
