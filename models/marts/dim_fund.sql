-- Fund/offering dimension. Grain: one row per fund.
select
    {{ dbt_surrogate_key(['fund_id']) }} as fund_key,   -- surrogate
    fund_id,                                            -- natural key
    fund_name,
    asset_class,
    structure,
    manager,
    vintage_year,
    inception_date
from {{ ref('stg_funds') }}
