-- Conformed date dimension (Kimball). A single date dim is reused across facts
-- and can be ROLE-PLAYED (e.g., joined as trade_date AND settle_date via aliases).
-- Grain: one row per calendar day across the data's active range.
with bounds as (
    select
        least( (select min(txn_date) from {{ ref('stg_transactions') }}),
               (select min(as_of_month) from {{ ref('stg_nav_monthly') }}) ) as start_d,
        greatest((select max(txn_date) from {{ ref('stg_transactions') }}),
                 (select max(as_of_month) from {{ ref('stg_nav_monthly') }})) as end_d
),
spine as (
    select cast(gs as date) as date_day
    from bounds,
         generate_series(bounds.start_d, bounds.end_d, interval 1 day) as t(gs)
)
select
    cast(strftime(date_day, '%Y%m%d') as integer) as date_key,   -- surrogate key
    date_day,
    extract(year  from date_day)  as year,
    extract(month from date_day)  as month,
    extract(day   from date_day)  as day,
    date_trunc('month', date_day) as month_start,
    extract(dow   from date_day)  as day_of_week,
    (extract(dow from date_day) in (0,6)) as is_weekend
from spine
