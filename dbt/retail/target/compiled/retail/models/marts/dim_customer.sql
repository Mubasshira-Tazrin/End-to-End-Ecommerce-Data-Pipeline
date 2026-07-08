-- Gold: customer dimension (SCD-1, one row per customer).
-- Surrogate key hashed from the stable natural key (customer_id).
with customers as (
    select * from `retail`.`silver`.`stg_customers`
)

select
    md5(cast(concat(coalesce(cast(customer_id as string), '_dbt_utils_surrogate_key_null_')) as string)) as customer_key,
    customer_id,
    concat_ws(' ', first_name, last_name)   as full_name,
    email,
    city,
    country,
    signup_date
from customers