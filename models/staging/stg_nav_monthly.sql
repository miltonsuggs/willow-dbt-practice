with source as (select * from {{ ref('nav_monthly') }})
select
    cast(fund_id as integer)     as fund_id,
    cast(as_of_month as date)    as as_of_month,
    cast(nav_per_unit as double) as nav_per_unit
from source
