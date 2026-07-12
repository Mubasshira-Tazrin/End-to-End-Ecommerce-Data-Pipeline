
  
    
        create or replace table `retail`.`silver`.`stg_order_items`
      
      
    using delta
  
      
      
      
      
      
      
      
      
      as
      -- Silver: cleaned order line items. No updated_at in source, so dedupe on the PK itself
-- (order_item_id is a strictly-increasing serial and unique — this just guards against
-- Airbyte append duplicates).
with source as (
    select * from `retail`.`raw`.`order_items`
),

deduped as (
    select
        *,
        row_number() over (
            partition by order_item_id
            order by order_item_id desc
        ) as _rn
    from source
    where order_item_id is not null
)

select
    cast(order_item_id as bigint)           as order_item_id,
    cast(order_id as bigint)                as order_id,
    cast(product_id as bigint)              as product_id,
    cast(quantity as int)                   as quantity,
    cast(unit_price as decimal(10,2))       as unit_price
from deduped
where _rn = 1
  