-- Investor dimension. Grain: one row per investor (current attributes).
-- Uses a SURROGATE KEY (hashed) alongside the natural/business key investor_id.
-- (Point-in-time accreditation history lives in the SCD2 snapshot, not here.)
select
    {{ dbt_surrogate_key(['investor_id']) }} as investor_key,   -- surrogate
    investor_id,                                                -- natural/business key
    full_name,
    state,
    signup_date,
    referral_source,
    referred_by_investor_id
from {{ ref('stg_investors') }}
