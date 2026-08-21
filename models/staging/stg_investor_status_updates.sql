-- Note: the raw feed contains EXACT duplicate rows on purpose. We do NOT
-- dedupe here (staging stays faithful to source); dedup happens in intermediate.
with source as (select * from {{ ref('investor_status_updates') }})
select
    cast(update_id as integer)    as update_id,
    cast(investor_id as integer)  as investor_id,
    status,
    cast(updated_at as timestamp) as updated_at,
    source                        as source_system
from source
