
  
    
        create or replace table `retail`.`gold`.`fact_sales`
      
      
    using delta
  
      
      
      
      
      
      
      
      
      as
      -- Gold: sales fact. GRAIN = one order line item.
-- Joins order_items -> orders (for customer + date) -> payments (method/status),
-- carries surrogate FKs to every dimension, and computes line_amount.
with order_items as (
    select * from `retail`.`silver`.`stg_order_items`
),

orders as (
    select * from `retail`.`silver`.`stg_orders`
),

-- one payment per order in the source; aggregate defensively so a stray duplicate
-- can never fan out the fact grain.
payments as (
    select
        order_id,
        max(payment_method) as payment_method,
        max(payment_status) as payment_status
    from `retail`.`silver`.`stg_payments`
    group by order_id
)

select
    md5(cast(concat(coalesce(cast(oi.order_item_id as string), '_dbt_utils_surrogate_key_null_')) as string)) as sales_key,
    oi.order_id,
    oi.order_item_id,
    md5(cast(concat(coalesce(cast(o.customer_id as string), '_dbt_utils_surrogate_key_null_')) as string))   as customer_key,
    md5(cast(concat(coalesce(cast(oi.product_id as string), '_dbt_utils_surrogate_key_null_')) as string))   as product_key,
    cast(date_format(o.order_date, 'yyyyMMdd') as int)          as date_key,
    oi.quantity,
    oi.unit_price,
    oi.quantity * oi.unit_price                                 as line_amount,
    p.payment_method,
    p.payment_status
from order_items oi
join orders o
    on oi.order_id = o.order_id
left join payments p
    on oi.order_id = p.order_id
  