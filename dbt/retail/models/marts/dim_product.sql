-- Gold: product dimension (SCD-1, one row per product).
with products as (
    select * from {{ ref('stg_products') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,
    product_id,
    product_name,
    category,
    brand,
    price
from products
