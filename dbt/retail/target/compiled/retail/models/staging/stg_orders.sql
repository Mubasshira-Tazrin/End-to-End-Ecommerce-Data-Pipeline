-- Silver: cleaned & standardized orders. Status upper-cased to a stable code.
with source as (
    select * from `retail`.`raw`.`orders`
),

deduped as (
    select
        *,
        row_number() over (
            partition by order_id
            order by updated_at desc
        ) as _rn
    from source
    where order_id is not null
)

select
    cast(order_id as bigint)                as order_id,
    cast(customer_id as bigint)             as customer_id,
    cast(order_date as date)                as order_date,
    upper(trim(status))                     as status,
    cast(total_amount as decimal(12,2))     as total_amount,
    cast(updated_at as timestamp)           as updated_at
from deduped
where _rn = 1