
    
    

select
    sales_key as unique_field,
    count(*) as n_records

from `retail`.`gold`.`fact_sales`
where sales_key is not null
group by sales_key
having count(*) > 1


