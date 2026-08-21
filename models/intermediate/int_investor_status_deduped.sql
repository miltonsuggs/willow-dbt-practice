-- Intermediate: remove the exact-duplicate rows from the raw status feed so the
-- snapshot / SCD logic sees clean input. Keeps the earliest update_id per key.
select
    update_id, investor_id, status, updated_at, source_system
from {{ ref('stg_investor_status_updates') }}
qualify row_number() over (
    partition by investor_id, status, updated_at
    order by update_id
) = 1
