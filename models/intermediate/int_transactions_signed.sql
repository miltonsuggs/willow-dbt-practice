-- Intermediate: add the signed cash-flow convention once, so every downstream
-- fact/report shares one definition (DRY). Materialized EPHEMERAL -> this compiles
-- into a CTE inside its consumers; no standalone object is created.
select
    transaction_id,
    investor_id,
    fund_id,
    txn_date,
    txn_type,
    amount,
    {{ signed_cash_flow('txn_type', 'amount') }} as cash_flow
from {{ ref('stg_transactions') }}
