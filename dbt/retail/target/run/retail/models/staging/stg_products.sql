
  
    
        create or replace table `retail`.`silver`.`stg_products`
      
      
    using delta
  
      
      
      
      
      
      
      
      
      as
      -- Silver: cleaned & standardized products.
with source as (
    select * from `retail`.`raw`.`products`
),

deduped as (
    select
        *,
        row_number() over (
            partition by product_id
            order by updated_at desc
        ) as _rn
    from source
    where product_id is not null
)

select
    cast(product_id as bigint)              as product_id,
    trim(product_name)                      as product_name,
    initcap(trim(category))                 as category,
    trim(brand)                             as brand,
    cast(price as decimal(10,2))            as price,
    cast(in_stock as boolean)               as in_stock,
    cast(updated_at as timestamp)           as updated_at
from deduped
where _rn = 1
  