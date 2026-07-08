-- Gold: sales fact. GRAIN = one order line item.
-- Joins order_items -> orders (for customer + date) -> payments (method/status),
-- carries surrogate FKs to every dimension, and computes line_amount.
with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

-- one payment per order in the source; aggregate defensively so a stray duplicate
-- can never fan out the fact grain.
payments as (
    select
        order_id,
        max(payment_method) as payment_method,
        max(payment_status) as payment_status
    from {{ ref('stg_payments') }}
    group by order_id
)

select
    {{ dbt_utils.generate_surrogate_key(['oi.order_item_id']) }} as sales_key,
    oi.order_id,
    oi.order_item_id,
    {{ dbt_utils.generate_surrogate_key(['o.customer_id']) }}   as customer_key,
    {{ dbt_utils.generate_surrogate_key(['oi.product_id']) }}   as product_key,
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
