
  
    
        create or replace table `retail`.`gold`.`dim_product`
      
      
    using delta
  
      
      
      
      
      
      
      
      
      as
      -- Gold: product dimension (SCD-1, one row per product).
with products as (
    select * from `retail`.`silver`.`stg_products`
)

select
    md5(cast(concat(coalesce(cast(product_id as string), '_dbt_utils_surrogate_key_null_')) as string)) as product_key,
    product_id,
    product_name,
    category,
    brand,
    price
from products
  