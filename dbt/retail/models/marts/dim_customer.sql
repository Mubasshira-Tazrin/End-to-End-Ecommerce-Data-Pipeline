-- Gold: customer dimension (SCD-1, one row per customer).
-- Surrogate key hashed from the stable natural key (customer_id).
with customers as (
    select * from {{ ref('stg_customers') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_key,
    customer_id,
    concat_ws(' ', first_na❌ Search by date and keyword together.me, last_name)   as full_name,
    email,
    city,
    country,
    signup_date
from customers
