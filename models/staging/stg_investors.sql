-- Staging: 1:1 with the raw seed. Rename, cast, light-clean only.
-- Materialized as a VIEW (cheap, always reflects latest raw).
with source as (
    select * from {{ ref('investors') }}
)
select
    cast(investor_id as integer)              as investor_id,
    first_name,
    last_name,
    first_name || ' ' || last_name            as full_name,
    upper(trim(state))                        as state,
    cast(signup_date as date)                 as signup_date,
    referral_source,
    cast(referred_by_investor_id as integer)  as referred_by_investor_id
from source
