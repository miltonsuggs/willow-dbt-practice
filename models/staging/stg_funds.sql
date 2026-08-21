with source as (select * from {{ ref('funds') }})
select
    cast(fund_id as integer)      as fund_id,
    fund_name,
    asset_class,
    structure,
    manager,
    cast(vintage_year as integer) as vintage_year,
    cast(inception_date as date)  as inception_date
from source
