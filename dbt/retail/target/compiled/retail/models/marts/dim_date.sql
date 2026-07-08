-- Gold: date dimension. A CONTINUOUS calendar (no gaps) spanning the order dates,
-- generated with Databricks sequence()+explode so the sales-trend line has every day.
with bounds as (
    select
        min(order_date) as start_date,
        max(order_date) as end_date
    from `retail`.`silver`.`stg_orders`
),

spine as (
    select explode(sequence(start_date, end_date, interval 1 day)) as date
    from bounds
)

select
    cast(date_format(date, 'yyyyMMdd') as int)  as date_key,
    date,
    day(date)                                   as day,
    month(date)                                 as month,
    quarter(date)                               as quarter,
    year(date)                                  as year
from spine