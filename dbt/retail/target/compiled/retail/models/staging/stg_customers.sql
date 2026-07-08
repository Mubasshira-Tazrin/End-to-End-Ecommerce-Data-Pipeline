-- Silver: cleaned & standardized customers.
-- Dedupe (keep latest by updated_at), trim strings, lower-case email, upper-case country code.
with source as (
    select * from `retail`.`raw`.`customers`
),

deduped as (
    select
        *,
        row_number() over (
            partition by customer_id
            order by updated_at desc
        ) as _rn
    from source
    where customer_id is not null           -- drop rows missing the natural key
)

select
    cast(customer_id as bigint)             as customer_id,
    trim(first_name)                        as first_name,
    trim(last_name)                         as last_name,
    lower(trim(email))                      as email,
    trim(phone)                             as phone,
    initcap(trim(city))                     as city,
    upper(trim(country))                    as country,
    cast(signup_date as date)               as signup_date,
    cast(updated_at as timestamp)           as updated_at
from deduped
where _rn = 1