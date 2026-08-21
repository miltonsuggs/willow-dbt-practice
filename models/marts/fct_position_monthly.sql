-- PERIODIC SNAPSHOT fact table.
-- GRAIN: one row per fund per month.
-- NAV is a SEMI-ADDITIVE measure: you may average it across time or sum it
-- across funds within ONE month, but you must NOT sum it across months.
-- (Documenting additivity is a core dimensional-modeling skill.)
select
    df.fund_key,
    dd.date_key,
    n.fund_id,
    n.as_of_month,
    n.nav_per_unit
from {{ ref('stg_nav_monthly') }} n
left join {{ ref('dim_fund') }} df on df.fund_id  = n.fund_id
left join {{ ref('dim_date') }} dd on dd.date_day = n.as_of_month
