-- Silver: cleaned & standardized payments. Method + status upper-cased to stable codes.
with source as (
    select * from {{ source('bronze', 'payments') }}
),

deduped as (
    select
        *,
        row_number() over (
            partition by payment_id
            order by updated_at desc
        ) as _rn
    from source
    where payment_id is not null
)

select
    cast(payment_id as bigint)              as payment_id,
    cast(order_id as bigint)                as order_id,
    upper(trim(payment_method))             as payment_method,
    cast(amount as decimal(12,2))           as amount,
    upper(trim(payment_status))             as payment_status,
    cast(payment_date as date)              as payment_date,
    cast(updated_at as timestamp)           as updated_at
from deduped
where _rn = 1
